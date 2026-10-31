%% 8-bit RGB images. Row 0 is the top.
-module(rt_image).

-export([
    new/2,
    from_pixels/3,
    encode/1,
    set_pixel/4,
    pixel/3,
    to_ppm/1,
    to_png/1,
    save_png/2
]).
-export_type([image/0]).

-record(image, {
    width :: non_neg_integer(),
    height :: non_neg_integer(),
    pixels :: binary()
}).

-opaque image() :: #image{}.

-spec new(non_neg_integer(), non_neg_integer()) -> image().
new(Width, Height) ->
    from_pixels(Width, Height, binary:copy(<<0, 0, 0>>, Width * Height)).

%% An image from its pixels, three bytes each, row by row.
-spec from_pixels(non_neg_integer(), non_neg_integer(), binary()) -> image().
from_pixels(Width, Height, Pixels) when byte_size(Pixels) =:= 3 * Width * Height ->
    #image{width = Width, height = Height, pixels = Pixels}.

%% A colour as three bytes, clamping each channel to [0, 1].
-spec encode(rt_vec3:vec3()) -> <<_:24>>.
encode({R, G, B}) ->
    <<(to_byte(R)), (to_byte(G)), (to_byte(B))>>.

to_byte(C) ->
    max(0, trunc(255.99 * min(C, 1.0))).

-spec set_pixel(image(), non_neg_integer(), non_neg_integer(), rt_vec3:vec3()) -> image().
set_pixel(#image{pixels = Pixels} = Img, X, Y, Color) ->
    I = index(Img, X, Y),
    <<Before:I/binary, _:3/binary, After/binary>> = Pixels,
    Img#image{pixels = <<Before/binary, (encode(Color))/binary, After/binary>>}.

-spec pixel(image(), non_neg_integer(), non_neg_integer()) -> {byte(), byte(), byte()}.
pixel(#image{pixels = Pixels} = Img, X, Y) ->
    <<R, G, B>> = binary:part(Pixels, index(Img, X, Y), 3),
    {R, G, B}.

index(#image{width = W, height = H}, X, Y) when X >= 0, X < W, Y >= 0, Y < H ->
    3 * (Y * W + X);
index(_Img, X, Y) ->
    error({out_of_bounds, X, Y}).

%% Binary (P6) PPM encoding.
-spec to_ppm(image()) -> binary().
to_ppm(#image{width = W, height = H, pixels = Pixels}) ->
    Header = io_lib:format("P6~n~B ~B~n255~n", [W, H]),
    iolist_to_binary([Header, Pixels]).

%% PNG encoding: 8-bit RGB, compressed with zlib, with no filtering.
-spec to_png(image()) -> binary().
to_png(#image{width = W, height = H, pixels = Pixels}) ->
    %% Each scanline starts with its filter type, 0 for none.
    Raw = <<<<0, Row/binary>> || <<Row:(3 * W)/binary>> <= Pixels>>,
    %% 8 bits per channel, RGB, deflate, no filtering, no interlacing.
    Header = <<W:32, H:32, 8, 2, 0, 0, 0>>,
    iolist_to_binary([
        <<16#89, "PNG\r\n", 16#1A, "\n">>,
        chunk(<<"IHDR">>, Header),
        chunk(<<"IDAT">>, zlib:compress(Raw)),
        chunk(<<"IEND">>, <<>>)
    ]).

chunk(Type, Data) ->
    [<<(byte_size(Data)):32>>, Type, Data, <<(erlang:crc32([Type, Data])):32>>].

-spec save_png(image(), file:name_all()) -> ok | {error, file:posix() | badarg | terminated}.
save_png(Img, Path) ->
    file:write_file(Path, to_png(Img)).
