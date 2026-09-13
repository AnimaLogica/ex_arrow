//! Arrow compute kernel NIFs: filter, project, sort.
//!
//! All operations stay fully in native memory — the BEAM never sees column buffers.

use std::sync::Arc;

use arrow_array::{
    Array, ArrayRef, BooleanArray, Date32Array, Date64Array, Float32Array, Float64Array,
    Int16Array, Int32Array, Int64Array, Int8Array, LargeStringArray, RecordBatch, Scalar,
    StringArray, TimestampMicrosecondArray, TimestampMillisecondArray,
    TimestampNanosecondArray, TimestampSecondArray, UInt16Array, UInt32Array, UInt64Array,
    UInt8Array,
};
use arrow_ord::cmp;
use arrow_ord::sort::sort_to_indices;
use arrow_schema::{DataType, SortOptions, TimeUnit};
use arrow_select::filter::filter_record_batch;
use arrow_select::take::take;
use rustler::ResourceArc;
use rustler::{Atom, Env, Term};

use crate::resources::ExArrowRecordBatch;
use crate::util::{err_encode, ok_encode};

rustler::atoms! {
    field,
    scalar,
    call,
    eq,
    ne,
    gt,
    gte,
    lt,
    lte,
    atom_and = "and",
    atom_or = "or",
    atom_not = "not",
    date32,
    date64,
    timestamp_micros,
    timestamp_millis,
    timestamp_seconds,
    timestamp_nanos,
}

/// Filter rows from `batch` using the first column of `predicate_batch` (must be boolean).
///
/// Returns `{:ok, filtered_batch_ref}` or `{:error, msg}`.
#[rustler::nif]
pub fn compute_filter<'a>(
    env: Env<'a>,
    batch: ResourceArc<ExArrowRecordBatch>,
    predicate: ResourceArc<ExArrowRecordBatch>,
) -> Term<'a> {
    if predicate.batch.num_columns() == 0 {
        return err_encode(env, "predicate batch must have at least one column");
    }
    let bool_col = predicate.batch.column(0);
    let Some(bool_array) = bool_col.as_any().downcast_ref::<BooleanArray>() else {
        return err_encode(env, "predicate first column must be boolean");
    };
    match filter_record_batch(&batch.batch, bool_array) {
        Ok(filtered) => ok_encode(
            env,
            ResourceArc::new(ExArrowRecordBatch { batch: filtered }),
        ),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

/// Evaluate an encoded `Compute.Expression` AST to a boolean mask and filter `batch`.
///
/// Encoding (Elixir → term tree):
/// - `{:field, name}`
/// - `{:scalar, value}` where value is bool/int/float/utf8 or
///   `{:date32|:date64|:timestamp_*, i}`
/// - `{:call, op, [args...]}` with op in eq/ne/gt/gte/lt/lte/and/or/not
#[rustler::nif]
pub fn compute_filter_expr<'a>(
    env: Env<'a>,
    batch: ResourceArc<ExArrowRecordBatch>,
    encoded: Term<'a>,
) -> Term<'a> {
    let expr = match decode_expr(encoded) {
        Ok(e) => e,
        Err(msg) => return err_encode(env, &msg),
    };
    let mask = match eval_to_bool(&batch.batch, &expr) {
        Ok(m) => m,
        Err(msg) => return err_encode(env, &msg),
    };
    match filter_record_batch(&batch.batch, &mask) {
        Ok(filtered) => ok_encode(
            env,
            ResourceArc::new(ExArrowRecordBatch { batch: filtered }),
        ),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

// ── Expression AST (M2 residual filter) ──────────────────────────────────────

#[derive(Debug, Clone)]
enum Expr {
    Field(String),
    Scalar(ScalarValue),
    Call(Op, Vec<Expr>),
}

#[derive(Debug, Clone, Copy)]
enum Op {
    Eq,
    Ne,
    Gt,
    Gte,
    Lt,
    Lte,
    And,
    Or,
    Not,
}

#[derive(Debug, Clone)]
enum ScalarValue {
    Bool(bool),
    Int(i64),
    Float(f64),
    Utf8(String),
    Date32(i32),
    Date64(i64),
    TimestampMicros(i64),
    TimestampMillis(i64),
    TimestampSeconds(i64),
    TimestampNanos(i64),
}

#[derive(Debug)]
enum Value {
    Array(ArrayRef),
    Lit(ScalarValue),
}

fn decode_expr(term: Term<'_>) -> Result<Expr, String> {
    let tuple = rustler::types::tuple::get_tuple(term)
        .map_err(|_| "expression must be a tuple {:field|:scalar|:call, ...}")?;
    if tuple.is_empty() {
        return Err("empty expression tuple".into());
    }
    let tag: Atom = tuple[0]
        .decode()
        .map_err(|_| "expression tag must be an atom")?;
    if tag == field() {
        if tuple.len() != 2 {
            return Err("{:field, name} expects exactly 2 elements".into());
        }
        let name: String = tuple[1]
            .decode()
            .map_err(|_| "field name must be a UTF-8 string")?;
        return Ok(Expr::Field(name));
    }
    if tag == scalar() {
        if tuple.len() != 2 {
            return Err("{:scalar, value} expects exactly 2 elements".into());
        }
        return Ok(Expr::Scalar(decode_scalar(tuple[1])?));
    }
    if tag == call() {
        if tuple.len() != 3 {
            return Err("{:call, op, args} expects exactly 3 elements".into());
        }
        let op = decode_op(tuple[1])?;
        let list: rustler::types::list::ListIterator = tuple[2]
            .decode()
            .map_err(|_| "call args must be a list")?;
        let args: Result<Vec<_>, _> = list.map(decode_expr).collect();
        let args = args?;
        match op {
            Op::Not => {
                if args.len() != 1 {
                    return Err(":not expects exactly one argument".into());
                }
            }
            Op::And | Op::Or | Op::Eq | Op::Ne | Op::Gt | Op::Gte | Op::Lt | Op::Lte => {
                if args.len() != 2 {
                    return Err(format!("{:?} expects exactly two arguments", op));
                }
            }
        }
        return Ok(Expr::Call(op, args));
    }
    Err("expression tag must be :field, :scalar, or :call".into())
}

fn decode_op(term: Term<'_>) -> Result<Op, String> {
    let a: Atom = term.decode().map_err(|_| "call op must be an atom")?;
    if a == eq() {
        Ok(Op::Eq)
    } else if a == ne() {
        Ok(Op::Ne)
    } else if a == gt() {
        Ok(Op::Gt)
    } else if a == gte() {
        Ok(Op::Gte)
    } else if a == lt() {
        Ok(Op::Lt)
    } else if a == lte() {
        Ok(Op::Lte)
    } else if a == atom_and() {
        Ok(Op::And)
    } else if a == atom_or() {
        Ok(Op::Or)
    } else if a == atom_not() {
        Ok(Op::Not)
    } else {
        Err("unsupported call op (eq ne gt gte lt lte and or not)".into())
    }
}

fn decode_scalar(term: Term<'_>) -> Result<ScalarValue, String> {
    if let Ok(b) = term.decode::<bool>() {
        return Ok(ScalarValue::Bool(b));
    }
    if let Ok(i) = term.decode::<i64>() {
        return Ok(ScalarValue::Int(i));
    }
    if let Ok(f) = term.decode::<f64>() {
        return Ok(ScalarValue::Float(f));
    }
    if let Ok(s) = term.decode::<String>() {
        return Ok(ScalarValue::Utf8(s));
    }
    let tuple = rustler::types::tuple::get_tuple(term).map_err(|_| {
        "scalar must be bool, integer, float, UTF-8 string, or {:date32|:date64|:timestamp_*, i}"
            .to_string()
    })?;
    if tuple.len() != 2 {
        return Err("temporal scalar expects {:unit, integer}".into());
    }
    let unit: Atom = tuple[0]
        .decode()
        .map_err(|_| "temporal scalar unit must be an atom")?;
    let v: i64 = tuple[1]
        .decode()
        .map_err(|_| "temporal scalar value must be an integer")?;
    if unit == date32() {
        let d = i32::try_from(v).map_err(|_| format!("date32 value {v} out of range"))?;
        Ok(ScalarValue::Date32(d))
    } else if unit == date64() {
        Ok(ScalarValue::Date64(v))
    } else if unit == timestamp_micros() {
        Ok(ScalarValue::TimestampMicros(v))
    } else if unit == timestamp_millis() {
        Ok(ScalarValue::TimestampMillis(v))
    } else if unit == timestamp_seconds() {
        Ok(ScalarValue::TimestampSeconds(v))
    } else if unit == timestamp_nanos() {
        Ok(ScalarValue::TimestampNanos(v))
    } else {
        Err("unsupported temporal scalar unit".into())
    }
}

fn eval_to_bool(batch: &RecordBatch, expr: &Expr) -> Result<BooleanArray, String> {
    let value = eval_value(batch, expr)?;
    value_as_bool(value, batch.num_rows())
}

fn eval_value(batch: &RecordBatch, expr: &Expr) -> Result<Value, String> {
    match expr {
        Expr::Field(name) => {
            let col = batch.column_by_name(name).ok_or_else(|| {
                format!("column '{}' not found", name)
            })?;
            Ok(Value::Array(Arc::clone(col)))
        }
        Expr::Scalar(s) => Ok(Value::Lit(s.clone())),
        Expr::Call(op, args) => match op {
            Op::And => {
                let left = value_as_bool(eval_value(batch, &args[0])?, batch.num_rows())?;
                let right = value_as_bool(eval_value(batch, &args[1])?, batch.num_rows())?;
                arrow_arith::boolean::and(&left, &right).map_err(|e| e.to_string())
                    .map(|a| Value::Array(Arc::new(a) as ArrayRef))
            }
            Op::Or => {
                let left = value_as_bool(eval_value(batch, &args[0])?, batch.num_rows())?;
                let right = value_as_bool(eval_value(batch, &args[1])?, batch.num_rows())?;
                arrow_arith::boolean::or(&left, &right).map_err(|e| e.to_string())
                    .map(|a| Value::Array(Arc::new(a) as ArrayRef))
            }
            Op::Not => {
                let inner = value_as_bool(eval_value(batch, &args[0])?, batch.num_rows())?;
                arrow_arith::boolean::not(&inner)
                    .map_err(|e| e.to_string())
                    .map(|a| Value::Array(Arc::new(a) as ArrayRef))
            }
            Op::Eq | Op::Ne | Op::Gt | Op::Gte | Op::Lt | Op::Lte => {
                let left = eval_value(batch, &args[0])?;
                let right = eval_value(batch, &args[1])?;
                eval_cmp(left, right, *op, batch.num_rows())
                    .map(|a| Value::Array(Arc::new(a) as ArrayRef))
            }
        },
    }
}

fn value_as_bool(value: Value, len: usize) -> Result<BooleanArray, String> {
    match value {
        Value::Array(arr) => {
            let Some(b) = arr.as_any().downcast_ref::<BooleanArray>() else {
                return Err(format!(
                    "expected boolean expression result, got column type {:?}",
                    arr.data_type()
                ));
            };
            if b.len() != len {
                return Err(format!(
                    "boolean mask length {} does not match batch rows {}",
                    b.len(),
                    len
                ));
            }
            Ok(b.clone())
        }
        Value::Lit(ScalarValue::Bool(b)) => Ok(BooleanArray::from(vec![b; len])),
        Value::Lit(other) => Err(format!(
            "expected boolean expression result, got scalar {:?}",
            other
        )),
    }
}

fn eval_cmp(left: Value, right: Value, op: Op, len: usize) -> Result<BooleanArray, String> {
    match (left, right) {
        (Value::Array(l), Value::Array(r)) => {
            if l.len() != r.len() {
                return Err(format!(
                    "cannot compare arrays of lengths {} and {}",
                    l.len(),
                    r.len()
                ));
            }
            // `&dyn Array` implements Datum; pass `&&dyn Array` so it coerces to `&dyn Datum`.
            apply_cmp_dyn(l.as_ref(), r.as_ref(), op)
        }
        (Value::Array(l), Value::Lit(s)) => {
            let scalar_arr = make_scalar_array(&s, l.data_type())?;
            let scalar = Scalar::new(scalar_arr);
            let lhs: &dyn Array = l.as_ref();
            match op {
                Op::Eq => cmp::eq(&lhs, &scalar),
                Op::Ne => cmp::neq(&lhs, &scalar),
                Op::Gt => cmp::gt(&lhs, &scalar),
                Op::Gte => cmp::gt_eq(&lhs, &scalar),
                Op::Lt => cmp::lt(&lhs, &scalar),
                Op::Lte => cmp::lt_eq(&lhs, &scalar),
                Op::And | Op::Or | Op::Not => unreachable!("boolean ops handled separately"),
            }
            .map_err(|e| e.to_string())
        }
        (Value::Lit(s), Value::Array(r)) => {
            let scalar_arr = make_scalar_array(&s, r.data_type())?;
            let scalar = Scalar::new(scalar_arr);
            let rhs: &dyn Array = r.as_ref();
            match op {
                Op::Eq => cmp::eq(&scalar, &rhs),
                Op::Ne => cmp::neq(&scalar, &rhs),
                Op::Gt => cmp::gt(&scalar, &rhs),
                Op::Gte => cmp::gt_eq(&scalar, &rhs),
                Op::Lt => cmp::lt(&scalar, &rhs),
                Op::Lte => cmp::lt_eq(&scalar, &rhs),
                Op::And | Op::Or | Op::Not => unreachable!("boolean ops handled separately"),
            }
            .map_err(|e| e.to_string())
        }
        (Value::Lit(l), Value::Lit(r)) => {
            let dt = infer_lit_compare_type(&l, &r)?;
            let la = make_scalar_array(&l, &dt)?;
            let ra = make_scalar_array(&r, &dt)?;
            let ls = Scalar::new(la);
            let rs = Scalar::new(ra);
            let one = match op {
                Op::Eq => cmp::eq(&ls, &rs),
                Op::Ne => cmp::neq(&ls, &rs),
                Op::Gt => cmp::gt(&ls, &rs),
                Op::Gte => cmp::gt_eq(&ls, &rs),
                Op::Lt => cmp::lt(&ls, &rs),
                Op::Lte => cmp::lt_eq(&ls, &rs),
                Op::And | Op::Or | Op::Not => unreachable!("boolean ops handled separately"),
            }
            .map_err(|e| e.to_string())?;
            let flag = one.value(0);
            Ok(BooleanArray::from(vec![flag; len]))
        }
    }
}

fn apply_cmp_dyn(left: &dyn Array, right: &dyn Array, op: Op) -> Result<BooleanArray, String> {
    match op {
        Op::Eq => cmp::eq(&left, &right),
        Op::Ne => cmp::neq(&left, &right),
        Op::Gt => cmp::gt(&left, &right),
        Op::Gte => cmp::gt_eq(&left, &right),
        Op::Lt => cmp::lt(&left, &right),
        Op::Lte => cmp::lt_eq(&left, &right),
        Op::And | Op::Or | Op::Not => unreachable!("boolean ops handled separately"),
    }
    .map_err(|e| e.to_string())
}

fn infer_lit_compare_type(l: &ScalarValue, r: &ScalarValue) -> Result<DataType, String> {
    match (l, r) {
        (ScalarValue::Bool(_), ScalarValue::Bool(_)) => Ok(DataType::Boolean),
        (ScalarValue::Int(_), ScalarValue::Int(_)) => Ok(DataType::Int64),
        (ScalarValue::Float(_), ScalarValue::Float(_))
        | (ScalarValue::Int(_), ScalarValue::Float(_))
        | (ScalarValue::Float(_), ScalarValue::Int(_)) => Ok(DataType::Float64),
        (ScalarValue::Utf8(_), ScalarValue::Utf8(_)) => Ok(DataType::Utf8),
        (ScalarValue::Date32(_), ScalarValue::Date32(_)) => Ok(DataType::Date32),
        (ScalarValue::Date64(_), ScalarValue::Date64(_))
        | (ScalarValue::Date32(_), ScalarValue::Date64(_))
        | (ScalarValue::Date64(_), ScalarValue::Date32(_)) => Ok(DataType::Date64),
        (ScalarValue::TimestampMicros(_), _) | (_, ScalarValue::TimestampMicros(_)) => {
            Ok(DataType::Timestamp(TimeUnit::Microsecond, None))
        }
        (ScalarValue::TimestampMillis(_), _) | (_, ScalarValue::TimestampMillis(_)) => {
            Ok(DataType::Timestamp(TimeUnit::Millisecond, None))
        }
        (ScalarValue::TimestampSeconds(_), _) | (_, ScalarValue::TimestampSeconds(_)) => {
            Ok(DataType::Timestamp(TimeUnit::Second, None))
        }
        (ScalarValue::TimestampNanos(_), _) | (_, ScalarValue::TimestampNanos(_)) => {
            Ok(DataType::Timestamp(TimeUnit::Nanosecond, None))
        }
        _ => Err(format!(
            "cannot compare scalars {:?} and {:?}",
            l, r
        )),
    }
}

fn make_scalar_array(value: &ScalarValue, data_type: &DataType) -> Result<ArrayRef, String> {
    match (value, data_type) {
        (ScalarValue::Int(v), DataType::Int64) => {
            Ok(Arc::new(Int64Array::from(vec![*v])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Int32) => {
            let i = i32::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for Int32 column")
            })?;
            Ok(Arc::new(Int32Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Int16) => {
            let i = i16::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for Int16 column")
            })?;
            Ok(Arc::new(Int16Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Int8) => {
            let i = i8::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for Int8 column")
            })?;
            Ok(Arc::new(Int8Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::UInt64) => {
            if *v < 0 {
                return Err(format!("filter value {v} out of range for UInt64 column"));
            }
            Ok(Arc::new(UInt64Array::from(vec![*v as u64])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::UInt32) => {
            let i = u32::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for UInt32 column")
            })?;
            Ok(Arc::new(UInt32Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::UInt16) => {
            let i = u16::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for UInt16 column")
            })?;
            Ok(Arc::new(UInt16Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::UInt8) => {
            let i = u8::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for UInt8 column")
            })?;
            Ok(Arc::new(UInt8Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Float(v), DataType::Float64) => {
            Ok(Arc::new(Float64Array::from(vec![*v])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Float64) => {
            let f = *v as f64;
            // Use i128 on the round-trip so saturating f64→i64 casts (e.g.
            // i64::MAX) cannot mask precision loss.
            if (f as i128) != i128::from(*v) {
                return Err(format!(
                    "filter value {v} is not exactly representable as Float64"
                ));
            }
            Ok(Arc::new(Float64Array::from(vec![f])) as ArrayRef)
        }
        (ScalarValue::Float(v), DataType::Float32) => {
            let f = *v as f32;
            if (f as f64) != *v {
                return Err(format!(
                    "filter value {v} is not exactly representable as Float32"
                ));
            }
            Ok(Arc::new(Float32Array::from(vec![f])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Float32) => {
            let f = *v as f32;
            if (f as i64) != *v {
                return Err(format!(
                    "filter value {v} is not exactly representable as Float32"
                ));
            }
            Ok(Arc::new(Float32Array::from(vec![f])) as ArrayRef)
        }
        (ScalarValue::Utf8(s), DataType::Utf8) => {
            Ok(Arc::new(StringArray::from(vec![s.as_str()])) as ArrayRef)
        }
        (ScalarValue::Utf8(s), DataType::LargeUtf8) => {
            Ok(Arc::new(LargeStringArray::from(vec![s.as_str()])) as ArrayRef)
        }
        (ScalarValue::Bool(b), DataType::Boolean) => {
            Ok(Arc::new(BooleanArray::from(vec![*b])) as ArrayRef)
        }
        (ScalarValue::Date32(d), DataType::Date32) => {
            Ok(Arc::new(Date32Array::from(vec![*d])) as ArrayRef)
        }
        (ScalarValue::Date32(d), DataType::Date64) => {
            let millis = i64::from(*d)
                .checked_mul(86_400_000)
                .ok_or_else(|| format!("date32 {} overflows Date64 millis", d))?;
            Ok(Arc::new(Date64Array::from(vec![millis])) as ArrayRef)
        }
        (ScalarValue::Date64(d), DataType::Date64) => {
            Ok(Arc::new(Date64Array::from(vec![*d])) as ArrayRef)
        }
        (ScalarValue::Date64(d), DataType::Date32) => {
            if *d % 86_400_000 != 0 {
                return Err(format!(
                    "date64 value {d} is not an exact number of days for Date32"
                ));
            }
            let days = *d / 86_400_000;
            let i = i32::try_from(days).map_err(|_| {
                format!("date64 value {d} out of range for Date32")
            })?;
            Ok(Arc::new(Date32Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Date32) => {
            let i = i32::try_from(*v).map_err(|_| {
                format!("filter value {v} out of range for Date32 column")
            })?;
            Ok(Arc::new(Date32Array::from(vec![i])) as ArrayRef)
        }
        (ScalarValue::Int(v), DataType::Date64) => {
            Ok(Arc::new(Date64Array::from(vec![*v])) as ArrayRef)
        }
        (
            ScalarValue::TimestampMicros(v)
            | ScalarValue::TimestampMillis(v)
            | ScalarValue::TimestampSeconds(v)
            | ScalarValue::TimestampNanos(v)
            | ScalarValue::Int(v),
            DataType::Timestamp(unit, tz),
        ) => make_timestamp_scalar(value, *v, *unit, tz.clone()),
        _ => Err(format!(
            "cannot compare filter value {:?} against column type {:?}",
            value, data_type
        )),
    }
}

fn make_timestamp_scalar(
    original: &ScalarValue,
    raw: i64,
    unit: TimeUnit,
    tz: Option<Arc<str>>,
) -> Result<ArrayRef, String> {
    let micros = match original {
        ScalarValue::TimestampMicros(v) => *v,
        ScalarValue::TimestampMillis(v) => v
            .checked_mul(1_000)
            .ok_or_else(|| format!("timestamp millis {v} overflows micros"))?,
        ScalarValue::TimestampSeconds(v) => v
            .checked_mul(1_000_000)
            .ok_or_else(|| format!("timestamp seconds {v} overflows micros"))?,
        ScalarValue::TimestampNanos(v) => {
            if *v % 1_000 != 0 {
                return Err(format!(
                    "timestamp nanos {v} is not an exact number of microseconds"
                ));
            }
            *v / 1_000
        }
        ScalarValue::Int(v) => {
            // Bare integers are already in the column's unit (validate path).
            return timestamp_array_from_ticks(*v, unit, tz);
        }
        _ => raw,
    };
    let ticks = micros_to_unit(micros, unit)?;
    timestamp_array_from_ticks(ticks, unit, tz)
}

fn micros_to_unit(micros: i64, unit: TimeUnit) -> Result<i64, String> {
    match unit {
        TimeUnit::Microsecond => Ok(micros),
        TimeUnit::Millisecond => {
            if micros % 1_000 != 0 {
                return Err(format!(
                    "timestamp micros {micros} is not an exact number of milliseconds"
                ));
            }
            Ok(micros / 1_000)
        }
        TimeUnit::Second => {
            if micros % 1_000_000 != 0 {
                return Err(format!(
                    "timestamp micros {micros} is not an exact number of seconds"
                ));
            }
            Ok(micros / 1_000_000)
        }
        TimeUnit::Nanosecond => micros
            .checked_mul(1_000)
            .ok_or_else(|| format!("timestamp micros {micros} overflows nanos")),
    }
}

fn timestamp_array_from_ticks(
    ticks: i64,
    unit: TimeUnit,
    tz: Option<Arc<str>>,
) -> Result<ArrayRef, String> {
    // arrow-array constructors ignore tz on the array values; DataType carries tz.
    // Scalar::new uses the array's data_type, so build typed arrays then cast schema via
    // with_timezone when needed.
    match unit {
        TimeUnit::Second => {
            let arr = TimestampSecondArray::from(vec![ticks]);
            Ok(Arc::new(match tz {
                Some(tz) => arr.with_timezone(tz),
                None => arr,
            }) as ArrayRef)
        }
        TimeUnit::Millisecond => {
            let arr = TimestampMillisecondArray::from(vec![ticks]);
            Ok(Arc::new(match tz {
                Some(tz) => arr.with_timezone(tz),
                None => arr,
            }) as ArrayRef)
        }
        TimeUnit::Microsecond => {
            let arr = TimestampMicrosecondArray::from(vec![ticks]);
            Ok(Arc::new(match tz {
                Some(tz) => arr.with_timezone(tz),
                None => arr,
            }) as ArrayRef)
        }
        TimeUnit::Nanosecond => {
            let arr = TimestampNanosecondArray::from(vec![ticks]);
            Ok(Arc::new(match tz {
                Some(tz) => arr.with_timezone(tz),
                None => arr,
            }) as ArrayRef)
        }
    }
}

/// Project (select) a subset of columns from `batch` by name.
///
/// Returns `{:ok, projected_batch_ref}` or `{:error, msg}`.
#[rustler::nif]
pub fn compute_project<'a>(
    env: Env<'a>,
    batch: ResourceArc<ExArrowRecordBatch>,
    column_names: Vec<String>,
) -> Term<'a> {
    let schema = batch.batch.schema();
    let indices: Vec<usize> = match column_names
        .iter()
        .map(|name| {
            schema
                .index_of(name.as_str())
                .map_err(|_| format!("column '{}' not found", name))
        })
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(idx) => idx,
        Err(e) => return err_encode(env, e.as_str()),
    };
    match batch.batch.project(&indices) {
        Ok(projected) => ok_encode(
            env,
            ResourceArc::new(ExArrowRecordBatch { batch: projected }),
        ),
        Err(e) => err_encode(env, &e.to_string()),
    }
}

/// Sort `batch` by `column_name`.  `ascending = true` for ascending order.
///
/// Nulls are placed first regardless of sort direction.
/// Returns `{:ok, sorted_batch_ref}` or `{:error, msg}`.
#[rustler::nif]
pub fn compute_sort<'a>(
    env: Env<'a>,
    batch: ResourceArc<ExArrowRecordBatch>,
    column_name: String,
    ascending: bool,
) -> Term<'a> {
    let schema = batch.batch.schema();
    let col_idx = match schema.index_of(&column_name) {
        Ok(i) => i,
        Err(_) => return err_encode(env, &format!("column '{}' not found", column_name)),
    };
    let column: &Arc<dyn Array> = batch.batch.column(col_idx);
    let sort_opts = SortOptions {
        descending: !ascending,
        nulls_first: true,
    };
    let indices = match sort_to_indices(column.as_ref(), Some(sort_opts), None) {
        Ok(i) => i,
        Err(e) => return err_encode(env, &e.to_string()),
    };
    let new_columns: Vec<ArrayRef> = match batch
        .batch
        .columns()
        .iter()
        .map(|col| take(col.as_ref(), &indices, None).map_err(|e| e.to_string()))
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(cols) => cols,
        Err(e) => return err_encode(env, e.as_str()),
    };
    match RecordBatch::try_new(batch.batch.schema(), new_columns) {
        Ok(sorted) => ok_encode(env, ResourceArc::new(ExArrowRecordBatch { batch: sorted })),
        Err(e) => err_encode(env, &e.to_string()),
    }
}
