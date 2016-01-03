local ffi = require("ffi")
local format = string.format
local tostring = tostring
local tonumber = tonumber
local setmetatable = setmetatable
local insert = table.insert

module("imlib2")

ffi.cdef[[
/* opaque data types */
typedef void *Imlib_Context;
typedef struct{} Imlib_Image2;
typedef Imlib_Image2* Imlib_Image;
typedef void *Imlib_Color_Modifier;
typedef void *Imlib_Updates;
typedef struct{} Imlib_Font2;
typedef Imlib_Font2 *Imlib_Font;
typedef struct{} Imlib_Color_Range2;
typedef Imlib_Color_Range2 *Imlib_Color_Range;
typedef void *Imlib_Filter;
typedef struct _imlib_border Imlib_Border;
typedef struct _imlib_color Imlib_Color;
typedef struct{} ImlibPolygon2;
typedef ImlibPolygon2 *ImlibPolygon;

/* blending operations */
enum _imlib_operation
{
	IMLIB_OP_COPY,
	IMLIB_OP_ADD,
	IMLIB_OP_SUBTRACT,
	IMLIB_OP_RESHADE
};

enum _imlib_text_direction
{
	IMLIB_TEXT_TO_RIGHT = 0,
	IMLIB_TEXT_TO_LEFT = 1,
	IMLIB_TEXT_TO_DOWN = 2,
	IMLIB_TEXT_TO_UP = 3,
	IMLIB_TEXT_TO_ANGLE = 4
};

enum _imlib_load_error
{
	IMLIB_LOAD_ERROR_NONE,
	IMLIB_LOAD_ERROR_FILE_DOES_NOT_EXIST,
	IMLIB_LOAD_ERROR_FILE_IS_DIRECTORY,
	IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_READ,
	IMLIB_LOAD_ERROR_NO_LOADER_FOR_FILE_FORMAT,
	IMLIB_LOAD_ERROR_PATH_TOO_LONG,
	IMLIB_LOAD_ERROR_PATH_COMPONENT_NON_EXISTANT,
	IMLIB_LOAD_ERROR_PATH_COMPONENT_NOT_DIRECTORY,
	IMLIB_LOAD_ERROR_PATH_POINTS_OUTSIDE_ADDRESS_SPACE,
	IMLIB_LOAD_ERROR_TOO_MANY_SYMBOLIC_LINKS,
	IMLIB_LOAD_ERROR_OUT_OF_MEMORY,
	IMLIB_LOAD_ERROR_OUT_OF_FILE_DESCRIPTORS,
	IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_WRITE,
	IMLIB_LOAD_ERROR_OUT_OF_DISK_SPACE,
	IMLIB_LOAD_ERROR_UNKNOWN
};

typedef enum _imlib_operation Imlib_Operation;
typedef enum _imlib_load_error Imlib_Load_Error;
typedef enum _imlib_load_error ImlibLoadError;
typedef enum _imlib_text_direction Imlib_Text_Direction;

struct _imlib_border
{
	int left, right, top, bottom;
};

struct _imlib_color
{
	int alpha, red, green, blue;
};

Imlib_Image imlib_create_image(int width, int height);
Imlib_Image imlib_load_image(const char *file);
Imlib_Image imlib_load_image_immediately(const char *file);
Imlib_Image imlib_load_image_without_cache(const char *file);
Imlib_Image imlib_load_image_immediately_without_cache(const char *file);
Imlib_Image imlib_load_image_with_error_return(const char *file,
												Imlib_Load_Error *
												error_return);

Imlib_Image imlib_clone_image(void);
Imlib_Image imlib_create_cropped_image(int x, int y, int width,
										int height);
Imlib_Image imlib_create_cropped_scaled_image(int source_x, int source_y,
												int source_width,
												int source_height,
												int destination_width,
												int destination_height);

void imlib_free_image(void);
void imlib_free_image_and_decache(void);

/* query/modify image parameters */
int imlib_image_get_width(void);
int imlib_image_get_height(void);
const char *imlib_image_get_filename(void);
char imlib_image_has_alpha(void);
void imlib_image_get_border(Imlib_Border * border);
void imlib_image_set_border(Imlib_Border * border);
void imlib_image_set_format(const char *format);
char *imlib_image_format(void);
void imlib_image_set_has_alpha(char has_alpha);
void imlib_image_query_pixel(int x, int y, Imlib_Color * color_return);

void imlib_blend_image_onto_image(Imlib_Image source_image,
									char merge_alpha, int source_x,
									int source_y, int source_width,
									int source_height, int destination_x,
									int destination_y, int destination_width,
									int destination_height);

void imlib_context_set_dither_mask(char dither_mask);
void imlib_context_set_mask_alpha_threshold(int mask_alpha_threshold);
void imlib_context_set_anti_alias(char anti_alias);
void imlib_context_set_dither(char dither);
void imlib_context_set_blend(char blend);
void imlib_context_set_color_modifier(Imlib_Color_Modifier color_modifier);
void imlib_context_set_operation(Imlib_Operation operation);
void imlib_context_set_font(Imlib_Font font);
void imlib_context_set_direction(Imlib_Text_Direction direction);
void imlib_context_set_angle(double angle);
void imlib_context_set_color(int red, int green, int blue, int alpha);
void imlib_context_set_color_range(Imlib_Color_Range color_range);

void imlib_context_set_image(Imlib_Image image);
void imlib_context_set_cliprect(int x, int y, int w, int h);

char imlib_context_get_anti_alias(void);

int imlib_get_cache_size(void);
void imlib_set_cache_size(int bytes);

/* image modification */
void imlib_image_flip_horizontal(void);
void imlib_image_flip_vertical(void);
void imlib_image_flip_diagonal(void);
void imlib_image_orientate(int orientation);
void imlib_image_blur(int radius);
void imlib_image_sharpen(int radius);
void imlib_image_tile_horizontal(void);
void imlib_image_tile_vertical(void);
void imlib_image_tile(void);

/* fonts and text */
Imlib_Font imlib_load_font(const char *font_name);
void imlib_free_font(void);

/* NB! The four functions below are deprecated. */
int imlib_insert_font_into_fallback_chain(Imlib_Font font, Imlib_Font fallback_font);
void imlib_remove_font_from_fallback_chain(Imlib_Font fallback_font);
Imlib_Font imlib_get_prev_font_in_fallback_chain(Imlib_Font fn);
Imlib_Font imlib_get_next_font_in_fallback_chain(Imlib_Font fn);
/* NB! The four functions above are deprecated. */
void imlib_text_draw(int x, int y, const char *text);
void imlib_text_draw_with_return_metrics(int x, int y, const char *text,
											int *width_return,
											int *height_return,
											int *horizontal_advance_return,
											int *vertical_advance_return);

void imlib_get_text_size(const char *text, int *width_return,
							int *height_return);
void imlib_get_text_advance(const char *text, 
							int *horizontal_advance_return,
							int *vertical_advance_return);
int imlib_get_text_inset(const char *text);
void imlib_add_path_to_font_path(const char *path);
void imlib_remove_path_from_font_path(const char *path);
char **imlib_list_font_path(int *number_return);
int imlib_text_get_index_and_location(const char *text, int x, int y,
										int *char_x_return,
										int *char_y_return,
										int *char_width_return,
										int *char_height_return);
void imlib_text_get_location_at_index(const char *text, int index,
										int *char_x_return,
										int *char_y_return,
										int *char_width_return,
										int *char_height_return);
char **imlib_list_fonts(int *number_return);
void imlib_free_font_list(char **font_list, int number);
int imlib_get_font_cache_size(void);
void imlib_set_font_cache_size(int bytes);
void imlib_flush_font_cache(void);
int imlib_get_font_ascent(void);
int imlib_get_font_descent(void);
int imlib_get_maximum_font_ascent(void);
int imlib_get_maximum_font_descent(void);

/* drawing on images */
Imlib_Updates imlib_image_draw_pixel(int x, int y, char make_updates);
Imlib_Updates imlib_image_draw_line(int x1, int y1, int x2, int y2,
                                         char make_updates);
void imlib_image_draw_rectangle(int x, int y, int width, int height);
void imlib_image_fill_rectangle(int x, int y, int width, int height);
void imlib_image_copy_alpha_to_image(Imlib_Image image_source, int x,
                                          int y);
void imlib_image_copy_alpha_rectangle_to_image(Imlib_Image image_source,
                                                    int x, int y, int width,
                                                    int height,
                                                    int destination_x,
                                                    int destination_y);
void imlib_image_scroll_rect(int x, int y, int width, int height,
                                  int delta_x, int delta_y);
void imlib_image_copy_rect(int x, int y, int width, int height, int new_x,
                                int new_y);

/* polygons */
ImlibPolygon imlib_polygon_new(void);
void imlib_polygon_free(ImlibPolygon poly);
void imlib_polygon_add_point(ImlibPolygon poly, int x, int y);
void imlib_image_draw_polygon(ImlibPolygon poly, unsigned char closed);
void imlib_image_fill_polygon(ImlibPolygon poly);
void imlib_polygon_get_bounds(ImlibPolygon poly, int *px1, int *py1,
								int *px2, int *py2);
unsigned char imlib_polygon_contains_point(ImlibPolygon poly, int x,
											int y);

/* ellipses */
void imlib_image_draw_ellipse(int xc, int yc, int a, int b);
void imlib_image_fill_ellipse(int xc, int yc, int a, int b);

/* color ranges */
Imlib_Color_Range imlib_create_color_range(void);
void imlib_free_color_range(void);
void imlib_add_color_to_color_range(int distance_away);
void imlib_image_fill_color_range_rectangle(int x, int y, int width,
                                                 int height, double angle);

void imlib_save_image_with_error_return(const char *filename,
                                             Imlib_Load_Error * error_return);

void imlib_image_clear(void);
void imlib_image_clear_color(int r, int g, int b, int a);
]]

local lib = ffi.load("Imlib2")

local ERRORS = {
	IMLIB_LOAD_ERROR_FILE_DOES_NOT_EXIST = "file %q does not exist",
	IMLIB_LOAD_ERROR_FILE_IS_DIRECTORY = "file %q is a directory",
	IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_READ = "permission denied to read file %q",
	IMLIB_LOAD_ERROR_NO_LOADER_FOR_FILE_FORMAT = "no loader for the file format used in file %q",
	IMLIB_LOAD_ERROR_PATH_TOO_LONG = "path for file %q is too long",
	IMLIB_LOAD_ERROR_PATH_COMPONENT_NON_EXISTANT = "a component of path %q does not exist",
	IMLIB_LOAD_ERROR_PATH_COMPONENT_NOT_DIRECTORY = "a component of path %q is not a directory",
	IMLIB_LOAD_ERROR_PATH_POINTS_OUTSIDE_ADDRESS_SPACE = "path for file %q is outside address space",
	IMLIB_LOAD_ERROR_TOO_MANY_SYMBOLIC_LINKS = "path %q has too many symbolic links",
	IMLIB_LOAD_ERROR_OUT_OF_MEMORY = "not enough memory to write %q",
	IMLIB_LOAD_ERROR_OUT_OF_FILE_DESCRIPTORS = "ran out of file descriptors trying to access file %q",
	IMLIB_LOAD_ERROR_PERMISSION_DENIED_TO_WRITE = "denied write permission for file %q",
	IMLIB_LOAD_ERROR_OUT_OF_DISK_SPACE = "out of disk space writing to file %q",
	IMLIB_LOAD_ERROR_UNKNOWN = "unknown error when writing to file %q"
}

---------------------
-- Image Metatable --
---------------------

image = setmetatable({}, {
	__call = function(self,path)
		local err = ffi.new("Imlib_Load_Error [1]")
		local img = lib.imlib_load_image_with_error_return(path, err)

		if ERRORS[err[0]] then
			return false, ERRORS[err[0]]
		end
		return img
	end
})
image.__index = image

function image.new(w,h,alpha)
	local img = lib.imlib_create_image(w,h)
	img:clear()
	img:enableAlpha(alpha or false)
	return img
end

function image.setDrawColor(color)
	lib.imlib_context_set_color(color.r,color.g,color.b,color.a)
end

function image:__tostring()
	lib.imlib_context_set_image(self)
	return format("<imlib2.image [width=%i, height=%i]> (%p)", self:getWidth(), self:getHeight(), self)
end

function image:__gc()
	self:free()
end

function image:drawElipse(x, y, h, b, color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_ellipse(x, y, h, b)
end

function image:fillElipse(x, y, h, v, color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_fill_ellipse(x, y, h, v)
end

function image:drawPoly(poly, close)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_polygon(poly, close or false)
end

function image:fillPoly(poly, color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_fill_polygon(poly)
end

function image:drawRect(x,y,w,h,color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_rectangle(x,y,w,h)
end

function image:fillRect(x,y,w,h,color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_fill_rectangle(x,y,w,h)
end

function image:drawPixel(x,y,color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_pixel(x, y, false)
end

function image:drawLine(x1,y1,x2,y2,color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_line(x1, y1, x2, y2, false)
end

function image:drawText(font, text, x, y, color)
	if color then
		self.setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_context_set_font(font)
	lib.imlib_text_draw(x, y, tostring(text))
end

function image:clone()
	lib.imlib_context_set_image(self)
	return lib.imlib_clone_image()
end

function image:blendImage(image, alpha, x, y, w, h, dx, dy, dw, dh)
	lib.imlib_context_set_image(self)
	lib.imlib_blend_image_onto_image(image, alpha, x, y, w, h, dx, dy, dw, dh)
end

function image:getPixel(x,y)
	local c = ffi.new("Imlib_Color [1]")
	lib.imlib_image_query_pixel(x,y,c)
	return color(c[0].red,c[0].green,c[0].blue,c[0].alpha)
end

function image:getFilename()
	lib.imlib_context_set_image(self)
	local filename = lib.imlib_image_get_filename()
	if filename == nil then return end
	return filename
end

function image:getWidth()
	lib.imlib_context_set_image(self)
	return lib.imlib_image_get_width()
end

function image:getHeight()
	lib.imlib_context_set_image(self)
	return lib.imlib_image_get_height()
end

function image:getSize()
	return self:getWidth(), self:getHeight()
end

function image:getFormat()
	lib.imlib_context_set_image(self)
	local format = lib.imlib_image_format()
	if format == nil then return "unknown" end
	return ffi.string(format)
end

function image:free()
	lib.imlib_context_set_image(self)
	lib.imlib_free_image()
end

function image:save(path)
	path = path or self:getFilename()

	lib.imlib_context_set_image(self)
	local err = ffi.new("Imlib_Load_Error [1]")
	lib.imlib_save_image_with_error_return(path, err)

	if ERRORS[err[0]] then
		return false, ERRORS[err[0]]
	end
	return true
end

function image:enableAlpha(bool)
	lib.imlib_context_set_image(self)
	lib.imlib_image_set_has_alpha(bool)
end

function image:isAlphaEnabled()
	lib.imlib_context_set_image(self)
	return lib.imlib_image_has_alpha() == 1
end

function image:clear(color)
	lib.imlib_context_set_image(self)
	if color then
		lib.imlib_image_clear_color(color.r,color.g,color.b,color.a)
	else
		lib.imlib_image_clear()
	end
end

function image:flipHorizontal()
	lib.imlib_context_set_image(self)
	lib.imlib_image_flip_horizontal()
end

function image:flipVertical()
	lib.imlib_context_set_image(self)
	lib.imlib_image_flip_vertical()
end

function image:flipDiagonal()
	lib.imlib_context_set_image(self)
	lib.imlib_image_flip_diagonal()
end

function image:orientate(ang)
	lib.imlib_context_set_image(self)
	lib.imlib_image_orientate(ang)
end

function image:blur(redius)
	lib.imlib_context_set_image(self)
	lib.imlib_image_blur(redius)
end

function image:sharpen(redius)
	lib.imlib_context_set_image(self)
	lib.imlib_image_sharpen(redius)
end

function image:blur(redius)
	lib.imlib_context_set_image(self)
	lib.imlib_image_blur(redius)
end

function image:fillGradient(grad, x, y, w, h, ang)
	lib.imlib_context_set_image(self)
	lib.imlib_context_set_color_range(grad)
	imlib_image_fill_color_range_rectangle(x, y, w, h, ang)
end

function image:crop(x,y,w,h)
	lib.imlib_context_set_image(self)
	return lib.imlib_create_cropped_image(x,y,w,h)
end

ffi.metatype("Imlib_Image2", image)

--------------------
-- Poly Metatable --
--------------------

poly = setmetatable({}, {
	__call = function()
		return lib.imlib_polygon_new()
	end,
})
poly.__index = poly

function poly:__tostring()
	return format("<imlib2.poly> (%p)", self)
end

function poly:__gc()
	self:free()
end

function poly:addPoint(x,y)
	lib.imlib_polygon_add_point(self,x,y)
end

function poly:getBounds()
	local x1 = ffi.new("int [1]")
	local y1 = ffi.new("int [1]")
	local x2 = ffi.new("int [1]")
	local y2 = ffi.new("int [1]")
	lib.imlib_polygon_get_bounds(self, x1, y1, x2, y2);
	return x1[0], y1[0], x2[0], y2[0]
end

function poly:containsPoint(x, y)
	return lib.imlib_polygon_contains_point(self,x,y) == 1
end

function poly:free()
	lib.imlib_polygon_free(self)
end

ffi.metatype("ImlibPolygon2", poly)

--------------------
-- Font Metatable --
--------------------

font = setmetatable({}, {
	__call = function(self,path)
		local font = lib.imlib_load_font(path)
		if font == nil then return false, format("unable to find font %q", path) end
		return font
	end,
})
font.__index = font

function font.getPaths()
	local num = ffi.new("int [1]")
	local charArray = lib.imlib_list_font_path(num)
	local paths = {}
	for i=1,num[0] do
		insert(paths, ffi.string(charArray[num[0]-1]))
	end
	return paths
end

function font.addPath(path)
	lib.imlib_add_path_to_font_path(path)
end

function font.removePath(path)
	lib.imlib_remove_path_from_font_path(path)
end

function font:__tostring()
	lib.imlib_context_set_font(self)
	return format("<imlib2.font> (%p)", self)
end

function font:__gc()
	self:free()
end

function font:getSize(text)
	local w, h = ffi.new('int [1]'), ffi.new('int [1]')
	lib.imlib_context_set_font(self)
	lib.imlib_get_text_size(tostring(text), w, h)
	return w[0], h[0]
end

function font:getAdvance(str)
	local h, v = ffi.new('int [1]'), ffi.new('int [1]')
	lib.imlib_context_set_font(self)
	lib.imlib_get_text_advance(text, h, v)
	return h[0], v[0]
end

function font:getInset(str)
	lib.imlib_context_set_font(self)
	return lib.imlib_get_text_inset(str)
end

function font:getAscent()
	lib.imlib_context_set_font(self)
	return lib.imlib_get_font_ascent()
end

function font:getAscentMax()
	lib.imlib_context_set_font(self)
	return lib.imlib_get_maximum_font_ascent()
end

function getDescent()
	lib.imlib_context_set_font(self)
	return lib.imlib_get_font_descent()
end

function getDescentMax()
	lib.imlib_context_set_font(self)
	return lib.imlib_get_maximum_font_descent()
end

function font:free()
	lib.imlib_context_set_font(self)
	lib.imlib_free_font()
end

ffi.metatype("Imlib_Font2", font)

---------------------
-- Color Metatable --
---------------------

color = {}

setmetatable(color, {
	__call = function(self,r,g,b,a)
		return setmetatable({r = tonumber(r), g = tonumber(g), b = tonumber(b), a = tonumber(a) or 255}, color)
	end,
})

color.__index = color
color.white = color(255,255,255)
color.black = color(0,0,0)
color.red = color(255,0,0)
color.green = color(0,255,0)
color.blue = color(0,0,255)

function color:__tostring()
	return format("<imlib2.color [red=%i, green=%i, blue=%i, alpha=%i]> (%p)", self.r, self.g, self.b, self.a, self)
end

--------------------
-- Gradient Metatable --
--------------------

gradient = setmetatable({}, {
	__call = function()
		return lib.imlib_create_color_range()
	end,
})

gradient.__index = gradient

function gradient:__tostring()
	lib.imlib_context_set_font(self)
	return format("<imlib2.gradient> (%p)", self)
end

function gradient:__gc()
	self:free()
end

function gradient:free()
	lib.imlib_context_set_color_range(self)
	lib.imlib_free_color_range()
end

function gradient:addColor(color, offset)
	lib.imlib_context_set_color_range(self)
	setDrawColor(color)
	lib.imlib_add_color_to_color_range(offset)
end

ffi.metatype("Imlib_Color_Range2", gradient)

-------------------------
-- Main module methods --
-------------------------

function setAntiAlias(bool)
	lib.imlib_context_set_anti_alias(bool)
end

function getAntiAlias()
	return lib.imlib_context_get_anti_alias() == 1
end