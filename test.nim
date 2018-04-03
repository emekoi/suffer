proc foo[T](a, b: T) =
  echo "foo"

proc foo(a, b: float) =
  echo "bar"

template lerp[T](a, b, p: T): untyped =
  ((1 - p) * a + p * b)

echo uint8.high