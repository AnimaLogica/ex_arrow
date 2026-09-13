//! Parquet NIFs: read and write Parquet files and in-memory binary blobs.
//!
//! Readers are **lazily** iterated: each call to `parquet_stream_next` reads
//! the next row-group from the underlying file/bytes without pre-loading the
//! entire file into memory.  Supports projection, row-group selection,
//! predicate pushdown (`RowFilter`), and write options (compression, etc.).

use std::sync::Arc;
use std::sync::Mutex;

use arrow_array::{
    Array, ArrayRef, BooleanArray, Float64Array, Int64Array, RecordBatchReader, Scalar,
    StringArray,
};
use arrow_ord::cmp;
use arrow_schema::DataType;
use bytes::Bytes;
use parquet::arrow::arrow_reader::{
    ArrowPredicateFn, ParquetRecordBatchReaderBuilder, RowFilter,
};
use parquet::arrow::{ArrowWriter, ProjectionMask};
use parquet::basic::{Compression, ZstdLevel};
use parquet::file::metadata::ParquetMetaDataReader;
use parquet::file::properties::WriterProperties;
use parquet::file::statistics::Statistics;

use arrow::error::ArrowError;
use arrow::record_batch::RecordBatch;
use arrow_schema::SchemaRef;
use rustler::ResourceArc;
use rustler::{Encoder, Env, Term};

use crate::resources::{ExArrowRecordBatch, ExArrowSchema};
use crate::util::{err_encode, ok_encode};

rustler::atoms! {
    columns,
    row_groups,
    filters,
    compression,
    row_group_size,
    dictionary,
    none,
    uncompressed,
    snappy,
    zstd,
    lz4,
    gzip,
    eq,
    ne,
    gt,
    gte,
    lt,
    lte,
    atom_and = "and",
    atom_or = "or",
    nil,
    ok,
    done,
    encodings,
    path,
    num_values,
    min,
    max,
    index,
    num_rows,
    num_row_groups,
    total_byte_size,
    created_by,
    key_value_metadata,
    row_groups_total,
    row_groups_selected,
    row_groups_skipped,
}

// ── Resource ────────────────────────────────────────────────────────────────

/// Holds a lazy Parquet reader iterator; schema cached separately for
/// zero-cost `parquet_stream_schema` calls.
pub struct ExArrowParquetStream {
    pub schema: SchemaRef,
    pub reader: Mutex<Box<dyn Iterator<Item = Result<RecordBatch, ArrowError>> + Send>>,
    pub row_groups_total: usize,
    pub row_groups_selected: usize,
    pub row_groups_skipped: usize,
}

#[rustler::resource_impl]
impl rustler::Resource for ExArrowParquetStream {}

// ── Read options decoded from Elixir keyword lists ───────────────────────────

#[derive(Debug, Clone)]
enum FilterValue {
    Int(i64),
    Float(f64),
    Utf8(String),
    Bool(bool),
}

#[derive(Debug, Clone)]
enum FilterExpr {
    Eq(String, FilterValue),
    Ne(String, FilterValue),
    Gt(String, FilterValue),
    Gte(String, FilterValue),
    Lt(String, FilterValue),
    Lte(String, FilterValue),
    And(Vec<FilterExpr>),
    Or(Vec<FilterExpr>),
}

#[derive(Debug, Default)]
struct ReadOpts {
    columns: Option<Vec<String>>,
    row_groups: Option<Vec<usize>>,
    filter: Option<FilterExpr>,
}

fn decode_read_opts(term: Term<'_>) -> Result<ReadOpts, String> {
    if let Ok(atom) = term.decode::<rustler::Atom>() {
        if atom == nil() {
            return Ok(ReadOpts::default());
        }
    }
    let list: rustler::types::list::ListIterator = term
        .decode()
        .map_err(|_| "read opts must be a keyword list")?;
    let mut opts = ReadOpts::default();
    for item in list {
        let tuple =
            rustler::types::tuple::get_tuple(item).map_err(|_| "opt must be {key, value}")?;
        if tuple.len() != 2 {
            return Err("opt must be a 2-tuple".into());
        }
        let key: rustler::Atom = tuple[0].decode().map_err(|_| "opt key must be atom")?;
        if key == columns() {
            opts.columns = Some(decode_string_list(tuple[1])?);
        } else if key == row_groups() {
            opts.row_groups = Some(decode_usize_list(tuple[1])?);
        } else if key == filters() {
            opts.filter = Some(decode_filter_expr(tuple[1])?);
        } else {
            return Err(format!("unknown read option: {:?}", key));
        }
    }
    Ok(opts)
}

fn decode_string_list(term: Term<'_>) -> Result<Vec<String>, String> {
    let list: rustler::types::list::ListIterator =
        term.decode().map_err(|_| "columns must be a list of strings")?;
    list.map(|t| t.decode::<String>().map_err(|_| "column name must be a string".into()))
        .collect()
}

fn decode_usize_list(term: Term<'_>) -> Result<Vec<usize>, String> {
    let list: rustler::types::list::ListIterator =
        term.decode().map_err(|_| "row_groups must be a list of non-neg integers")?;
    list.map(|t| {
        let n: i64 = t
            .decode()
            .map_err(|_| "row_group index must be an integer".to_string())?;
        if n < 0 {
            return Err("row_group index must be non-negative".into());
        }
        Ok(n as usize)
    })
    .collect()
}

fn decode_filter_expr(term: Term<'_>) -> Result<FilterExpr, String> {
    let tuple = rustler::types::tuple::get_tuple(term)
        .map_err(|_| "filter must be a tuple like {:gt, col, value}")?;
    if tuple.is_empty() {
        return Err("empty filter tuple".into());
    }
    let op_atom: rustler::Atom = tuple[0]
        .decode()
        .map_err(|_| "filter op must be an atom")?;
    if op_atom == atom_and() || op_atom == atom_or() {
        if tuple.len() != 2 {
            return Err(":{and|or} filter expects {:and|:or, [filters]}".into());
        }
        let list: rustler::types::list::ListIterator = tuple[1]
            .decode()
            .map_err(|_| ":and/:or expects a list of filters")?;
        let children: Result<Vec<_>, _> = list.map(decode_filter_expr).collect();
        let children = children?;
        if children.is_empty() {
            return Err(":and/:or filter list must not be empty".into());
        }
        return Ok(if op_atom == atom_and() {
            FilterExpr::And(children)
        } else {
            FilterExpr::Or(children)
        });
    }
    if tuple.len() != 3 {
        return Err("comparison filter expects {:op, column, value}".into());
    }
    let col: String = tuple[1]
        .decode()
        .map_err(|_| "filter column must be a string")?;
    let val = decode_filter_value(tuple[2])?;
    if op_atom == eq() {
        Ok(FilterExpr::Eq(col, val))
    } else if op_atom == ne() {
        Ok(FilterExpr::Ne(col, val))
    } else if op_atom == gt() {
        Ok(FilterExpr::Gt(col, val))
    } else if op_atom == gte() {
        Ok(FilterExpr::Gte(col, val))
    } else if op_atom == lt() {
        Ok(FilterExpr::Lt(col, val))
    } else if op_atom == lte() {
        Ok(FilterExpr::Lte(col, val))
    } else {
        Err(
            "unsupported filter op (supported: eq ne gt gte lt lte and or)".into(),
        )
    }
}

fn decode_filter_value(term: Term<'_>) -> Result<FilterValue, String> {
    if let Ok(b) = term.decode::<bool>() {
        return Ok(FilterValue::Bool(b));
    }
    if let Ok(i) = term.decode::<i64>() {
        return Ok(FilterValue::Int(i));
    }
    if let Ok(f) = term.decode::<f64>() {
        return Ok(FilterValue::Float(f));
    }
    if let Ok(s) = term.decode::<String>() {
        return Ok(FilterValue::Utf8(s));
    }
    Err("filter value must be integer, float, string, or boolean".into())
}

// ── Write options ────────────────────────────────────────────────────────────

#[derive(Debug, Default)]
struct WriteOpts {
    compression: Option<Compression>,
    row_group_size: Option<usize>,
    dictionary: Option<bool>,
}

fn decode_write_opts(term: Term<'_>) -> Result<WriteOpts, String> {
    if let Ok(atom) = term.decode::<rustler::Atom>() {
        if atom == nil() {
            return Ok(WriteOpts::default());
        }
    }
    let list: rustler::types::list::ListIterator = term
        .decode()
        .map_err(|_| "write opts must be a keyword list")?;
    let mut opts = WriteOpts::default();
    for item in list {
        let tuple =
            rustler::types::tuple::get_tuple(item).map_err(|_| "opt must be {key, value}")?;
        if tuple.len() != 2 {
            return Err("opt must be a 2-tuple".into());
        }
        let key: rustler::Atom = tuple[0].decode().map_err(|_| "opt key must be atom")?;
        if key == compression() {
            opts.compression = Some(decode_compression(tuple[1])?);
        } else if key == row_group_size() {
            let n: i64 = tuple[1]
                .decode()
                .map_err(|_| "row_group_size must be a positive integer")?;
            if n <= 0 {
                return Err("row_group_size must be positive".into());
            }
            opts.row_group_size = Some(n as usize);
        } else if key == dictionary() {
            let b: bool = tuple[1]
                .decode()
                .map_err(|_| "dictionary must be a boolean")?;
            opts.dictionary = Some(b);
        } else {
            return Err(format!("unknown write option: {:?}", key));
        }
    }
    Ok(opts)
}

fn decode_compression(term: Term<'_>) -> Result<Compression, String> {
    if let Ok(tuple) = rustler::types::tuple::get_tuple(term) {
        if tuple.len() == 2 {
            let tag: rustler::Atom = tuple[0]
                .decode()
                .map_err(|_| "compression tuple tag must be atom")?;
            if tag == zstd() {
                let level: i64 = tuple[1]
                    .decode()
                    .map_err(|_| "zstd level must be an integer")?;
                let level_i32 = i32::try_from(level)
                    .map_err(|_| format!("zstd level {level} out of range"))?;
                let z = ZstdLevel::try_new(level_i32)
                    .map_err(|e| format!("invalid zstd level: {}", e))?;
                return Ok(Compression::ZSTD(z));
            }
            return Err("unsupported compression tuple (only {:zstd, level})".into());
        }
    }
    let atom: rustler::Atom = term
        .decode()
        .map_err(|_| "compression must be an atom or {:zstd, level}")?;
    if atom == none() || atom == uncompressed() {
        Ok(Compression::UNCOMPRESSED)
    } else if atom == snappy() {
        Ok(Compression::SNAPPY)
    } else if atom == zstd() {
        Ok(Compression::ZSTD(ZstdLevel::default()))
    } else if atom == lz4() {
        Ok(Compression::LZ4_RAW)
    } else if atom == gzip() {
        Ok(Compression::GZIP(Default::default()))
    } else {
        Err(
            "unsupported compression (supported: :none :snappy :zstd :lz4 :gzip)".into(),
        )
    }
}

fn build_writer_props(opts: &WriteOpts) -> WriterProperties {
    let mut b = WriterProperties::builder();
    if let Some(c) = opts.compression {
        b = b.set_compression(c);
    }
    if let Some(n) = opts.row_group_size {
        b = b.set_max_row_group_row_count(Some(n));
    }
    if let Some(d) = opts.dictionary {
        b = b.set_dictionary_enabled(d);
    }
    b.build()
}

// ── Filter evaluation helpers ────────────────────────────────────────────────

fn make_scalar(value: &FilterValue, data_type: &DataType) -> Result<ArrayRef, String> {
    match (value, data_type) {
        (FilterValue::Int(v), DataType::Int64) => {
            Ok(Arc::new(Int64Array::from(vec![*v])) as ArrayRef)
        }
        (FilterValue::Int(v), DataType::Int32) => {
            let i = i32::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for Int32 column")
            })?;
            Ok(Arc::new(arrow_array::Int32Array::from(vec![i])) as ArrayRef)
        }
        (FilterValue::Float(v), DataType::Float64) => {
            Ok(Arc::new(Float64Array::from(vec![*v])) as ArrayRef)
        }
        (FilterValue::Float(v), DataType::Float32) => {
            let f = *v as f32;
            // Reject values that are not exactly representable as f32 so Eq/Ne
            // (and other comparisons) cannot silently use a truncated scalar.
            if (f as f64) != *v {
                return Err(format!(
                    "filter value {v} is not exactly representable as Float32"
                ));
            }
            Ok(Arc::new(arrow_array::Float32Array::from(vec![f])) as ArrayRef)
        }
        (FilterValue::Utf8(s), DataType::Utf8) => {
            Ok(Arc::new(StringArray::from(vec![s.as_str()])) as ArrayRef)
        }
        (FilterValue::Bool(b), DataType::Boolean) => {
            Ok(Arc::new(BooleanArray::from(vec![*b])) as ArrayRef)
        }
        (FilterValue::Int(v), DataType::Float64) => {
            Ok(Arc::new(Float64Array::from(vec![*v as f64])) as ArrayRef)
        }
        _ => Err(format!(
            "cannot compare filter value {:?} against column type {:?}",
            value, data_type
        )),
    }
}

fn eval_cmp(
    array: &dyn Array,
    value: &FilterValue,
    op: &str,
) -> Result<BooleanArray, ArrowError> {
    let scalar_arr = make_scalar(value, array.data_type())
        .map_err(ArrowError::ComputeError)?;
    let scalar = Scalar::new(scalar_arr);
    match op {
        "eq" => cmp::eq(&array, &scalar),
        "ne" => cmp::neq(&array, &scalar),
        "gt" => cmp::gt(&array, &scalar),
        "gte" => cmp::gt_eq(&array, &scalar),
        "lt" => cmp::lt(&array, &scalar),
        "lte" => cmp::lt_eq(&array, &scalar),
        _ => Err(ArrowError::ComputeError(format!("unknown op {}", op))),
    }
}

fn eval_filter_on_batch(batch: &RecordBatch, expr: &FilterExpr) -> Result<BooleanArray, ArrowError> {
    match expr {
        FilterExpr::Eq(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "eq")
        }
        FilterExpr::Ne(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "ne")
        }
        FilterExpr::Gt(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "gt")
        }
        FilterExpr::Gte(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "gte")
        }
        FilterExpr::Lt(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "lt")
        }
        FilterExpr::Lte(col, v) => {
            let arr = batch
                .column_by_name(col)
                .ok_or_else(|| ArrowError::ComputeError(format!("column '{}' not found", col)))?;
            eval_cmp(arr.as_ref(), v, "lte")
        }
        FilterExpr::And(children) => {
            let mut acc: Option<BooleanArray> = None;
            for child in children {
                let mask = eval_filter_on_batch(batch, child)?;
                acc = Some(match acc {
                    None => mask,
                    Some(prev) => arrow_arith::boolean::and(&prev, &mask)?,
                });
            }
            acc.ok_or_else(|| ArrowError::ComputeError("empty and".into()))
        }
        FilterExpr::Or(children) => {
            let mut acc: Option<BooleanArray> = None;
            for child in children {
                let mask = eval_filter_on_batch(batch, child)?;
                acc = Some(match acc {
                    None => mask,
                    Some(prev) => arrow_arith::boolean::or(&prev, &mask)?,
                });
            }
            acc.ok_or_else(|| ArrowError::ComputeError("empty or".into()))
        }
    }
}

fn collect_filter_columns(expr: &FilterExpr, out: &mut Vec<String>) {
    match expr {
        FilterExpr::Eq(c, _)
        | FilterExpr::Ne(c, _)
        | FilterExpr::Gt(c, _)
        | FilterExpr::Gte(c, _)
        | FilterExpr::Lt(c, _)
        | FilterExpr::Lte(c, _) => {
            if !out.iter().any(|x| x == c) {
                out.push(c.clone());
            }
        }
        FilterExpr::And(xs) | FilterExpr::Or(xs) => {
            for x in xs {
                collect_filter_columns(x, out);
            }
        }
    }
}

fn validate_filter_types(schema: &arrow_schema::Schema, expr: &FilterExpr) -> Result<(), String> {
    match expr {
        FilterExpr::And(xs) | FilterExpr::Or(xs) => {
            for x in xs {
                validate_filter_types(schema, x)?;
            }
            Ok(())
        }
        FilterExpr::Eq(col, v)
        | FilterExpr::Ne(col, v)
        | FilterExpr::Gt(col, v)
        | FilterExpr::Gte(col, v)
        | FilterExpr::Lt(col, v)
        | FilterExpr::Lte(col, v) => {
            let field = schema
                .field_with_name(col)
                .map_err(|_| format!("filter column '{col}' not found in schema"))?;
            let _ = make_scalar(v, field.data_type())?;
            Ok(())
        }
    }
}

/// Resolve a filter column name to a Parquet physical leaf-column index.
///
/// Matches the leaf name or full dotted path (same namespace
/// `ProjectionMask::columns` uses). Arrow top-level field indices must not be
/// used here — nested Struct/List columns expand to multiple leaves.
fn parquet_leaf_index(
    schema_descr: &parquet::schema::types::SchemaDescriptor,
    name: &str,
) -> Option<usize> {
    schema_descr.columns().iter().position(|c| {
        c.name() == name || c.path().string() == name
    })
}

/// Return true if the row group *might* contain rows matching `expr` based on
/// column chunk min/max statistics. Unknown / missing stats → keep the group.
fn row_group_may_match(
    metadata: &parquet::file::metadata::ParquetMetaData,
    rg_idx: usize,
    schema_descr: &parquet::schema::types::SchemaDescriptor,
    expr: &FilterExpr,
) -> bool {
    match expr {
        FilterExpr::And(xs) => xs
            .iter()
            .all(|x| row_group_may_match(metadata, rg_idx, schema_descr, x)),
        FilterExpr::Or(xs) => xs
            .iter()
            .any(|x| row_group_may_match(metadata, rg_idx, schema_descr, x)),
        FilterExpr::Eq(col, v)
        | FilterExpr::Ne(col, v)
        | FilterExpr::Gt(col, v)
        | FilterExpr::Gte(col, v)
        | FilterExpr::Lt(col, v)
        | FilterExpr::Lte(col, v) => {
            let Some(leaf_idx) = parquet_leaf_index(schema_descr, col) else {
                return true;
            };
            let rg = metadata.row_group(rg_idx);
            let Some(chunk) = rg.columns().get(leaf_idx) else {
                return true;
            };
            let Some(stats) = chunk.statistics() else {
                return true;
            };
            stats_may_match(stats, expr, v)
        }
    }
}

fn int_range_may_match(expr: &FilterExpr, min: i64, max: i64, val: i64) -> bool {
    match expr {
        FilterExpr::Eq(_, _) => val >= min && val <= max,
        FilterExpr::Ne(_, _) => true, // cannot prune safely from a single min/max
        FilterExpr::Gt(_, _) => max > val,
        FilterExpr::Gte(_, _) => max >= val,
        FilterExpr::Lt(_, _) => min < val,
        FilterExpr::Lte(_, _) => min <= val,
        _ => true,
    }
}

fn float_range_may_match(expr: &FilterExpr, min: f64, max: f64, val: f64) -> bool {
    match expr {
        FilterExpr::Eq(_, _) => val >= min && val <= max,
        FilterExpr::Ne(_, _) => true,
        FilterExpr::Gt(_, _) => max > val,
        FilterExpr::Gte(_, _) => max >= val,
        FilterExpr::Lt(_, _) => min < val,
        FilterExpr::Lte(_, _) => min <= val,
        _ => true,
    }
}

fn stats_may_match(stats: &Statistics, expr: &FilterExpr, v: &FilterValue) -> bool {
    // Only prune when we have concrete min/max for supported physical types.
    // `:ne` is intentionally never pruned (see int_range_may_match).
    match (stats, v) {
        (Statistics::Int64(s), FilterValue::Int(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            int_range_may_match(expr, *min, *max, *val)
        }
        (Statistics::Int32(s), FilterValue::Int(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            int_range_may_match(expr, i64::from(*min), i64::from(*max), *val)
        }
        (Statistics::Double(s), FilterValue::Float(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            float_range_may_match(expr, *min, *max, *val)
        }
        (Statistics::Float(s), FilterValue::Float(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            float_range_may_match(expr, f64::from(*min), f64::from(*max), *val)
        }
        (Statistics::Boolean(s), FilterValue::Bool(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            // Arrow/Parquet treat false < true.
            let min_i = i64::from(*min);
            let max_i = i64::from(*max);
            let val_i = i64::from(*val);
            int_range_may_match(expr, min_i, max_i, val_i)
        }
        (Statistics::ByteArray(s), FilterValue::Utf8(val)) => {
            let (Some(min), Some(max)) = (s.min_opt(), s.max_opt()) else {
                return true;
            };
            let min_s = String::from_utf8_lossy(min.data()).into_owned();
            let max_s = String::from_utf8_lossy(max.data()).into_owned();
            match expr {
                FilterExpr::Eq(_, _) => {
                    val.as_str() >= min_s.as_str() && val.as_str() <= max_s.as_str()
                }
                FilterExpr::Ne(_, _) => true,
                FilterExpr::Gt(_, _) => max_s.as_str() > val.as_str(),
                FilterExpr::Gte(_, _) => max_s.as_str() >= val.as_str(),
                FilterExpr::Lt(_, _) => min_s.as_str() < val.as_str(),
                FilterExpr::Lte(_, _) => min_s.as_str() <= val.as_str(),
                _ => true,
            }
        }
        _ => true,
    }
}

fn apply_read_opts<T>(
    builder: ParquetRecordBatchReaderBuilder<T>,
    opts: ReadOpts,
) -> Result<(ParquetRecordBatchReaderBuilder<T>, usize, usize, usize), String>
where
    T: parquet::file::reader::ChunkReader + 'static,
{
    let metadata = builder.metadata().clone();
    let arrow_schema = builder.schema().clone();
    let total = metadata.num_row_groups();

    if let Some(ref filter) = opts.filter {
        validate_filter_types(arrow_schema.as_ref(), filter)?;
    }

    // Resolve row groups: explicit list ∩ statistics pruning.
    let mut selected: Vec<usize> = match &opts.row_groups {
        Some(rg) => {
            for &i in rg {
                if i >= total {
                    return Err(format!(
                        "row_group index {} out of range (file has {} row groups)",
                        i, total
                    ));
                }
            }
            rg.clone()
        }
        None => (0..total).collect(),
    };

    if let Some(ref filter) = opts.filter {
        let schema_descr = metadata.file_metadata().schema_descr();
        selected.retain(|&i| row_group_may_match(&metadata, i, schema_descr, filter));
    }

    let selected_count = selected.len();
    let skipped = total.saturating_sub(selected_count);

    // Build projection masks while we still borrow the builder's schema descriptor.
    let column_mask = opts.columns.as_ref().map(|cols| {
        let names: Vec<&str> = cols.iter().map(|s| s.as_str()).collect();
        ProjectionMask::columns(builder.parquet_schema(), names)
    });

    let filter_mask_and_expr = opts.filter.map(|filter| {
        let mut filter_cols = Vec::new();
        collect_filter_columns(&filter, &mut filter_cols);
        let names: Vec<&str> = filter_cols.iter().map(|s| s.as_str()).collect();
        let mask = ProjectionMask::columns(builder.parquet_schema(), names);
        (mask, filter)
    });

    let mut builder = builder.with_row_groups(selected);

    if let Some(mask) = column_mask {
        builder = builder.with_projection(mask);
    }

    if let Some((pred_mask, filter)) = filter_mask_and_expr {
        let pred = ArrowPredicateFn::new(pred_mask, move |batch| {
            eval_filter_on_batch(&batch, &filter)
        });
        builder = builder.with_row_filter(RowFilter::new(vec![Box::new(pred)]));
    }

    Ok((builder, total, selected_count, skipped))
}

fn build_stream<'a, T>(
    env: Env<'a>,
    builder: ParquetRecordBatchReaderBuilder<T>,
    opts: ReadOpts,
) -> Term<'a>
where
    T: parquet::file::reader::ChunkReader + 'static,
{
    let (builder, total, selected, skipped) = match apply_read_opts(builder, opts) {
        Ok(x) => x,
        Err(e) => return err_encode(env, &e),
    };
    let reader = match builder.build() {
        Ok(r) => r,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    // Use the reader's schema so projection pushdown is reflected.
    let schema = reader.schema();
    let stream = ExArrowParquetStream {
        schema,
        reader: Mutex::new(Box::new(reader)),
        row_groups_total: total,
        row_groups_selected: selected,
        row_groups_skipped: skipped,
    };
    ok_encode(env, ResourceArc::new(stream))
}

// ── Readers ─────────────────────────────────────────────────────────────────

/// Open a Parquet file for lazy row-group streaming.
/// `opts` is a keyword list: `:columns`, `:row_groups`, `:filters` (or `[]`).
#[rustler::nif]
pub fn parquet_reader_from_file<'a>(env: Env<'a>, path: String, opts: Term<'a>) -> Term<'a> {
    let read_opts = match decode_read_opts(opts) {
        Ok(o) => o,
        Err(e) => return err_encode(env, &e),
    };
    let file = match std::fs::File::open(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let builder = match ParquetRecordBatchReaderBuilder::try_new(file) {
        Ok(b) => b,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    build_stream(env, builder, read_opts)
}

/// Read Parquet data from an in-memory binary (lazy row-group streaming).
#[rustler::nif]
pub fn parquet_reader_from_binary<'a>(
    env: Env<'a>,
    binary: rustler::Binary,
    opts: Term<'a>,
) -> Term<'a> {
    let read_opts = match decode_read_opts(opts) {
        Ok(o) => o,
        Err(e) => return err_encode(env, &e),
    };
    let bytes = Bytes::copy_from_slice(binary.as_slice());
    let builder = match ParquetRecordBatchReaderBuilder::try_new(bytes) {
        Ok(b) => b,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    build_stream(env, builder, read_opts)
}

// ── Stream accessors ─────────────────────────────────────────────────────────

#[rustler::nif]
pub fn parquet_stream_schema<'a>(
    env: Env<'a>,
    stream: ResourceArc<ExArrowParquetStream>,
) -> Term<'a> {
    let handle = ExArrowSchema {
        schema: stream.schema.clone(),
    };
    ResourceArc::new(handle).encode(env)
}

/// Return `%{row_groups_total, row_groups_selected, row_groups_skipped}` for
/// observability of predicate/row-group pruning.
#[rustler::nif]
pub fn parquet_stream_read_stats<'a>(
    env: Env<'a>,
    stream: ResourceArc<ExArrowParquetStream>,
) -> Term<'a> {
    let map = rustler::types::map::map_new(env)
        .map_put(row_groups_total().encode(env), (stream.row_groups_total as u64).encode(env))
        .ok()
        .and_then(|m| {
            m.map_put(
                row_groups_selected().encode(env),
                (stream.row_groups_selected as u64).encode(env),
            )
            .ok()
        })
        .and_then(|m| {
            m.map_put(
                row_groups_skipped().encode(env),
                (stream.row_groups_skipped as u64).encode(env),
            )
            .ok()
        });
    match map {
        Some(m) => m,
        None => err_encode(env, "failed to build read stats map"),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parquet_stream_next<'a>(
    env: Env<'a>,
    stream: ResourceArc<ExArrowParquetStream>,
) -> Term<'a> {
    let mut guard = match stream.reader.lock() {
        Ok(g) => g,
        Err(_) => return err_encode(env, "parquet stream lock poisoned"),
    };
    match guard.next() {
        None => done().encode(env),
        Some(Err(e)) => err_encode(env, &e.to_string()),
        Some(Ok(batch)) => ok_encode(env, ResourceArc::new(ExArrowRecordBatch { batch })),
    }
}

// ── Writers ──────────────────────────────────────────────────────────────────

#[rustler::nif]
pub fn parquet_writer_to_file<'a>(
    env: Env<'a>,
    path: String,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
    opts: Term<'a>,
) -> Term<'a> {
    let write_opts = match decode_write_opts(opts) {
        Ok(o) => o,
        Err(e) => return err_encode(env, &e),
    };
    let file = match std::fs::File::create(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let props = build_writer_props(&write_opts);
    let mut writer = match ArrowWriter::try_new(file, schema.schema.clone(), Some(props)) {
        Ok(w) => w,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    for batch_ref in &batches {
        if let Err(e) = writer.write(&batch_ref.batch) {
            return err_encode(env, &e.to_string());
        }
    }
    match writer.close() {
        Ok(_) => ok().encode(env),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

#[rustler::nif]
pub fn parquet_writer_to_binary<'a>(
    env: Env<'a>,
    schema: ResourceArc<ExArrowSchema>,
    batches: Vec<ResourceArc<ExArrowRecordBatch>>,
    opts: Term<'a>,
) -> Term<'a> {
    let write_opts = match decode_write_opts(opts) {
        Ok(o) => o,
        Err(e) => return err_encode(env, &e),
    };
    let mut buf: Vec<u8> = Vec::new();
    let props = build_writer_props(&write_opts);
    {
        let mut writer = match ArrowWriter::try_new(&mut buf, schema.schema.clone(), Some(props)) {
            Ok(w) => w,
            Err(e) => return err_encode(env, &e.to_string()),
        };
        for batch_ref in &batches {
            if let Err(e) = writer.write(&batch_ref.batch) {
                return err_encode(env, &e.to_string());
            }
        }
        if let Err(e) = writer.close() {
            return err_encode(env, &e.to_string());
        }
    }
    let mut owned = match rustler::OwnedBinary::new(buf.len()) {
        Some(b) => b,
        None => return err_encode(env, "binary alloc"),
    };
    owned.as_mut_slice().copy_from_slice(&buf);
    let binary = rustler::Binary::from_owned(owned, env);
    ok_encode(env, binary)
}

// ── Metadata (footer only) ───────────────────────────────────────────────────

fn encode_metadata<'a>(env: Env<'a>, metadata: &parquet::file::metadata::ParquetMetaData) -> Term<'a> {
    let file_meta = metadata.file_metadata();
    let file_num_rows = file_meta.num_rows();
    let file_num_row_groups = metadata.num_row_groups() as i64;

    let mut rg_terms: Vec<Term<'a>> = Vec::with_capacity(metadata.num_row_groups());
    for i in 0..metadata.num_row_groups() {
        let rg = metadata.row_group(i);
        let mut col_terms: Vec<Term<'a>> = Vec::new();
        for col in rg.columns() {
            let col_path = col.column_path().string();
            let col_compression = format!("{}", col.compression());
            let (min_s, max_s) = match col.statistics() {
                Some(Statistics::Int64(s)) => (
                    s.min_opt().map(|v| v.to_string()),
                    s.max_opt().map(|v| v.to_string()),
                ),
                Some(Statistics::Int32(s)) => (
                    s.min_opt().map(|v| v.to_string()),
                    s.max_opt().map(|v| v.to_string()),
                ),
                Some(Statistics::Double(s)) => (
                    s.min_opt().map(|v| v.to_string()),
                    s.max_opt().map(|v| v.to_string()),
                ),
                Some(Statistics::Float(s)) => (
                    s.min_opt().map(|v| v.to_string()),
                    s.max_opt().map(|v| v.to_string()),
                ),
                Some(Statistics::ByteArray(s)) => (
                    s.min_opt()
                        .map(|v| String::from_utf8_lossy(v.data()).into_owned()),
                    s.max_opt()
                        .map(|v| String::from_utf8_lossy(v.data()).into_owned()),
                ),
                Some(Statistics::Boolean(s)) => (
                    s.min_opt().map(|v| v.to_string()),
                    s.max_opt().map(|v| v.to_string()),
                ),
                _ => (None, None),
            };
            let encoding_names: Vec<String> = col
                .encodings()
                .map(|e| format!("{e:?}"))
                .collect();
            let col_map = rustler::types::map::map_new(env);
            let col_map = put_atom_key(env, col_map, path(), col_path.encode(env));
            let col_map = put_atom_key(env, col_map, compression(), col_compression.encode(env));
            let col_map = put_atom_key(env, col_map, encodings(), encoding_names.encode(env));
            let col_map = put_atom_key(env, col_map, num_values(), col.num_values().encode(env));
            let col_map = match min_s {
                Some(s) => put_atom_key(env, col_map, min(), s.encode(env)),
                None => put_atom_key(env, col_map, min(), nil().encode(env)),
            };
            let col_map = match max_s {
                Some(s) => put_atom_key(env, col_map, max(), s.encode(env)),
                None => put_atom_key(env, col_map, max(), nil().encode(env)),
            };
            col_terms.push(col_map);
        }
        let rg_map = rustler::types::map::map_new(env);
        let rg_map = put_atom_key(env, rg_map, index(), (i as i64).encode(env));
        let rg_map = put_atom_key(env, rg_map, num_rows(), rg.num_rows().encode(env));
        let rg_map = put_atom_key(env, rg_map, total_byte_size(), rg.total_byte_size().encode(env));
        let rg_map = put_atom_key(env, rg_map, columns(), col_terms.encode(env));
        rg_terms.push(rg_map);
    }

    let mut kv: Vec<Term<'a>> = Vec::new();
    if let Some(meta) = file_meta.key_value_metadata() {
        for pair in meta {
            let key = pair.key.clone();
            let val = pair.value.clone().unwrap_or_default();
            kv.push((key, val).encode(env));
        }
    }

    let mut out = rustler::types::map::map_new(env);
    out = put_atom_key(env, out, num_rows(), file_num_rows.encode(env));
    out = put_atom_key(env, out, num_row_groups(), file_num_row_groups.encode(env));
    out = put_atom_key(
        env,
        out,
        created_by(),
        file_meta
            .created_by()
            .unwrap_or("")
            .to_string()
            .encode(env),
    );
    out = put_atom_key(env, out, row_groups(), rg_terms.encode(env));
    out = put_atom_key(env, out, key_value_metadata(), kv.encode(env));
    ok_encode(env, out)
}

fn put_atom_key<'a>(
    env: Env<'a>,
    map: Term<'a>,
    key: rustler::Atom,
    value: Term<'a>,
) -> Term<'a> {
    map.map_put(key.encode(env), value).unwrap_or(map)
}

#[rustler::nif]
pub fn parquet_metadata_from_file<'a>(env: Env<'a>, path: String) -> Term<'a> {
    let file = match std::fs::File::open(&path) {
        Ok(f) => f,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    match ParquetMetaDataReader::new().parse_and_finish(&file) {
        Ok(meta) => encode_metadata(env, &meta),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

#[rustler::nif]
pub fn parquet_metadata_from_binary<'a>(env: Env<'a>, binary: rustler::Binary) -> Term<'a> {
    let bytes = Bytes::copy_from_slice(binary.as_slice());
    match ParquetMetaDataReader::new().parse_and_finish(&bytes) {
        Ok(meta) => encode_metadata(env, &meta),
        Err(e) => err_encode(env, &e.to_string()),
    }
}
