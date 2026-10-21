defmodule Raytracer.Rng do
  @moduledoc """
  A small, fast pseudo-random number generator (SplitMix64), the same as the
  other versions use, so that scenes and renders are identical.

  The state is immutable: each function returns its result and the new state,
  which must be passed to the next call.
  """

  import Bitwise

  # Integers over 59 bits are bignums, allocated on the heap, which made the
  # generator three times slower. So the 64-bit state is kept as two
  # 32-bit halves, and the arithmetic is split up so that no intermediate
  # result needs more than 59 bits.
  @opaque t :: {hi :: non_neg_integer, lo :: non_neg_integer}

  @mask32 0xFFFF_FFFF
  @scale 1.0 / (1 <<< 53)

  @spec new(integer) :: t
  def new(seed), do: {seed >>> 32 &&& @mask32, seed &&& @mask32}

  @spec next_u64(t) :: {non_neg_integer, t}
  def next_u64(rng) do
    {hi, lo, rng} = next(rng)
    {hi <<< 32 ||| lo, rng}
  end

  @doc "A uniformly distributed float in [0, 1)."
  @spec next_f64(t) :: {float, t}
  def next_f64(rng) do
    {hi, lo, rng} = next(rng)
    # The top 53 bits fill a float's mantissa exactly.
    {((hi <<< 21) + (lo >>> 11)) * @scale, rng}
  end

  defp next({hi, lo}) do
    # Adds 0x9E3779B97F4A7C15.
    lo = lo + 0x7F4A7C15
    hi = hi + 0x9E3779B9 + (lo >>> 32) &&& @mask32
    lo = lo &&& @mask32
    {zh, zl} = xor_shift(hi, lo, 30) |> mul(0xBF58476D, 0x1CE4E5B9)
    {zh, zl} = xor_shift(zh, zl, 27) |> mul(0x94D049BB, 0x133111EB)
    {zh, zl} = xor_shift(zh, zl, 31)
    {zh, zl, {hi, lo}}
  end

  # z ^ (z >> n), for 0 < n < 32.
  defp xor_shift(hi, lo, n) do
    {bxor(hi, hi >>> n), bxor(lo, (lo >>> n ||| hi <<< (32 - n)) &&& @mask32)}
  end

  # z * c mod 2^64, where c is (ch, cl). A product of two 32-bit numbers can
  # need 64 bits, so one of them is split into 16-bit halves first.
  defp mul({hi, lo}, ch, cl) do
    # lo * cl = l0 + l1 * 2^16
    l0 = (lo &&& 0xFFFF) * cl
    l1 = (lo >>> 16) * cl
    low = l0 + ((l1 &&& 0xFFFF) <<< 16)
    carry = (low >>> 32) + (l1 >>> 16)
    {carry + mul32(hi, cl) + mul32(lo, ch) &&& @mask32, low &&& @mask32}
  end

  # a * b mod 2^32.
  defp mul32(a, b) do
    (a &&& 0xFFFF) * b + (((a >>> 16) * b &&& 0xFFFF) <<< 16) &&& @mask32
  end
end
