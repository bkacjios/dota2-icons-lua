local ffi = require("ffi")
local format = string.format
local tostring = tostring

module(...)

ffi.cdef[[
/* opaque data types */
typedef void *Imlib_Context;
typedef struct{} Imlib_Image2;
typedef Imlib_Image2* Imlib_Image;
typedef void *Imlib_Color_Modifier;
typedef void *Imlib_Updates;
typedef struct{} Imlib_Font2;
typedef Imlib_Font2 *Imlib_Font;
typedef void *Imlib_Color_Range;
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

/* Encodings known to Imlib2 (so far) */
enum _imlib_TTF_encoding
{
   IMLIB_TTF_ENCODING_ISO_8859_1,
   IMLIB_TTF_ENCODING_ISO_8859_2,
   IMLIB_TTF_ENCODING_ISO_8859_3,
   IMLIB_TTF_ENCODING_ISO_8859_4,
   IMLIB_TTF_ENCODING_ISO_8859_5
};

typedef enum _imlib_operation Imlib_Operation;
typedef enum _imlib_load_error Imlib_Load_Error;
typedef enum _imlib_load_error ImlibLoadError;
typedef enum _imlib_text_direction Imlib_Text_Direction;
typedef enum _imlib_TTF_encoding Imlib_TTF_Encoding;

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
void imlib_free_image(void);
void imlib_free_image_and_decache(void);

/* query/modify image parameters */
int imlib_image_get_width(void);
int imlib_image_get_height(void);
const char *imlib_image_get_filename(void);
unsigned int *imlib_image_get_data(void);
unsigned int*imlib_image_get_data_for_reading_only(void);
void imlib_image_put_back_data(unsigned int * data);
char imlib_image_has_alpha(void);
void imlib_image_set_changes_on_disk(void);
void imlib_image_get_border(Imlib_Border * border);
void imlib_image_set_border(Imlib_Border * border);
void imlib_image_set_format(const char *format);
void imlib_image_set_irrelevant_format(char irrelevant);
void imlib_image_set_irrelevant_border(char irrelevant);
void imlib_image_set_irrelevant_alpha(char irrelevant);
char *imlib_image_format(void);
void imlib_image_set_has_alpha(char has_alpha);
void imlib_image_query_pixel(int x, int y, Imlib_Color * color_return);
void imlib_image_query_pixel_hsva(int x, int y, float *hue, float *saturation, float *value, int *alpha);
void imlib_image_query_pixel_hlsa(int x, int y, float *hue, float *lightness, float *saturation, int *alpha);
void imlib_image_query_pixel_cmya(int x, int y, int *cyan, int *magenta, int *yellow, int *alpha);

void imlib_context_set_font(Imlib_Font font);
void imlib_context_set_color(int red, int green, int blue, int alpha);
void imlib_context_set_image(Imlib_Image image);

int imlib_image_get_width(void);
int imlib_image_get_height(void);

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

/* color modifiers */
Imlib_Color_Modifier imlib_create_color_modifier(void);
void imlib_free_color_modifier(void);
void imlib_modify_color_modifier_gamma(double gamma_value);
void imlib_modify_color_modifier_brightness(double brightness_value);
void imlib_modify_color_modifier_contrast(double contrast_value);
void imlib_set_color_modifier_tables(unsigned char * red_table,
                                          unsigned char * green_table,
                                          unsigned char * blue_table,
                                          unsigned char * alpha_table);
void imlib_get_color_modifier_tables(unsigned char * red_table,
                                          unsigned char * green_table,
                                          unsigned char * blue_table,
                                          unsigned char * alpha_table);
void imlib_reset_color_modifier(void);
void imlib_apply_color_modifier(void);
void imlib_apply_color_modifier_to_rectangle(int x, int y, int width,
                                                  int height);

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
void imlib_image_fill_hsva_color_range_rectangle(int x, int y, int width,
                                                      int height, double angle);
/* saving */
void imlib_save_image(const char *filename);
void imlib_save_image_with_error_return(const char *filename,
                                             Imlib_Load_Error * error_return);

void imlib_image_clear(void);
void imlib_image_clear_color(int r, int g, int b, int a);
]]

local lib = ffi.load("Imlib2")

local IMAGE = {}
IMAGE.__index = IMAGE

function IMAGE:__tostring()
	lib.imlib_context_set_image(self)
	return format("<imlib2.image [width = %i] [height = %i]> (%p)", self:getWidth(), self:getHeight(), self)
end

function IMAGE:__gc()
	self:free()
end

function IMAGE:drawElipse(x, y, a, b, color)
	if color then
		self:setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_ellipse(x, y, a, b)
end

function IMAGE:fillElipse(x, y, a, b, color)
	if color then
		self:setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_fill_ellipse(x, y, a, b)
end

function IMAGE:drawPoly(poly, close)
	if color then
		self:setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_draw_polygon(poly, close or false)
end

function IMAGE:drawText(font, text, x, y, color)
	if color then
		self:setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_context_set_font(font)
	lib.imlib_text_draw(x, y, tostring(text))
end

function IMAGE:fillPoly(poly, color)
	if color then
		self:setDrawColor(color)
	end
	lib.imlib_context_set_image(self)
	lib.imlib_image_fill_polygon(poly)
end

function IMAGE:clone()
	lib.imlib_context_set_image(self)
	return lib.imlib_clone_image()
end

function IMAGE:getWidth()
	lib.imlib_context_set_image(self)
	return lib.imlib_image_get_width()
end

function IMAGE:getHeight()
	lib.imlib_context_set_image(self)
	return lib.imlib_image_get_height()
end

function IMAGE:setDrawColor(color)
	lib.imlib_context_set_color(color.r,color.g,color.b,color.a)
end

function IMAGE:free()
	lib.imlib_context_set_image(self)
	lib.imlib_free_image()
end

function IMAGE:save(path)
	lib.imlib_context_set_image(self)
	lib.imlib_save_image(path)
end

function IMAGE:enableAlpha(bool)
	lib.imlib_context_set_image(self)
	lib.imlib_image_set_has_alpha(bool)
end

function IMAGE:clear(color)
	lib.imlib_context_set_image(self)
	if color then
		imlib_image_clear_color(color.r,color.g,color.b,color.a)
	else
		lib.imlib_image_clear()
	end
end

ffi.metatype("Imlib_Image2", IMAGE)

local POLY = {}
POLY.__index = POLY

function POLY:__tostring()
	return format("<imlib2.poly> (%p)", self)
end

function POLY:__gc()
	self:free()
end

function POLY:addPoint(x,y)
	lib.imlib_polygon_add_point(self,x,y)
end

function POLY:free()
	lib.imlib_polygon_free(self)
end

ffi.metatype("ImlibPolygon2", POLY)

local FONT = {}
FONT.__index = FONT

function FONT:__tostring()
	lib.imlib_context_set_font(self)
	return format("<imlib2.font> (%p)", self)
end

function FONT:__gc()
	self:free()
end

function FONT:getSize(text)
	local w, h = ffi.new('int [1]'), ffi.new('int [1]')
	lib.imlib_context_set_font(self)
	lib.imlib_get_text_size(tostring(text), w, h)
	return w[0], h[0]
end

function FONT:free()
	lib.imlib_context_set_font(self)
	lib.imlib_free_font()
end

ffi.metatype("Imlib_Font2", FONT)

function create(w,h,alpha)
	local img = lib.imlib_create_image(w,h)
	img:clear()
	img:enableAlpha(alpha or false)
	return img
end

function image(path)
	return lib.imlib_load_image(path)
end

function color(r,g,b,a)
	return {r = r, g = g, b = b, a = a or 255}
end

function poly()
	return lib.imlib_polygon_new()
end

function font(path)
	return lib.imlib_load_font(path)
end