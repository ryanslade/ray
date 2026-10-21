defmodule Raytracer.Image do
  @moduledoc "8-bit RGB images. Row 0 is the top."

  @enforce_keys [:width, :height, :pixels]
  defstruct @enforce_keys

  def new(width, height) do
    %__MODULE__{width: width, height: height, pixels: :binary.copy(<<0, 0, 0>>, width * height)}
  end

  @doc "A colour as three bytes, clamping each channel to [0, 1]."
  def encode({r, g, b}), do: <<to_byte(r), to_byte(g), to_byte(b)>>

  defp to_byte(c) do
    b = 255.99 * min(c, 1.0)
    if b > 0.0, do: trunc(b), else: 0
  end

  @doc "Stores a colour, clamping each channel to [0, 1]."
  def set_pixel(%__MODULE__{} = img, x, y, color) do
    i = index(img, x, y)
    <<before::binary-size(i), _::binary-size(3), rest::binary>> = img.pixels
    %{img | pixels: <<before::binary, encode(color)::binary, rest::binary>>}
  end

  @doc "The pixel at (`x`, `y`) as `{r, g, b}`, each in [0, 255]."
  def pixel(%__MODULE__{} = img, x, y) do
    <<r, g, b>> = binary_part(img.pixels, index(img, x, y), 3)
    {r, g, b}
  end

  defp index(img, x, y) do
    unless x in 0..(img.width - 1)//1 and y in 0..(img.height - 1)//1 do
      raise ArgumentError, "pixel (#{x}, #{y}) is out of bounds"
    end

    3 * (y * img.width + x)
  end

  @doc "Binary (P6) PPM encoding."
  def to_ppm(%__MODULE__{} = img) do
    "P6\n#{img.width} #{img.height}\n255\n" <> img.pixels
  end

  def save_ppm(%__MODULE__{} = img, path), do: File.write(path, to_ppm(img))
end
