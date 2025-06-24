package main

//imports
import rl "vendor:raylib"
import "core:slice"
import "core:math/rand"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:log"

//Constants
WINDOW_SIZE :: 1000
CELL_SIZE :: 20
SQUARE_OUTLINE_THICKNESS :: f32(.5)
CANVAS_WIDTH :: CELL_SIZE * COLUMN_SIZE
CANVAS_LENGTH :: CELL_SIZE * ROW_SIZE
CANVAS_AREA :: CANVAS_WIDTH * CANVAS_LENGTH
ZOOM_MULTIPLIER :: 12
NUM_OF_SQUARES :: ROW_SIZE * COLUMN_SIZE
ROW_SIZE :: 4
COLUMN_SIZE :: 4
SQUARE_COLOR :: rl.LIGHTGRAY
GRID_COLOR :: rl.DARKGRAY
FONT_SIZE :: f32(18)
FONT_SPACING :: f32(1)
FONT_COLOR :: rl.BLACK

//Globals
squares : SquareManager
renderable : RenderManager
colors : ColorManager

//Buffers
num_buf : [8]byte


main :: proc() {
    context.logger = log.create_console_logger()
    log.info("Program started")

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "15 Puzzle")

    grid_color_i := insert_color(GRID_COLOR, &colors.arr)
    square_color_i := insert_color(SQUARE_COLOR, &colors.arr)
    grid_render := Renderable{grid_color_i, {0, 0}, CANVAS_WIDTH, CANVAS_LENGTH, true, true}

    grid : GridEntity
    grid = create_grid(grid_render, COLUMN_SIZE, ROW_SIZE, CELL_SIZE)

    rand_arr : [NUM_OF_SQUARES]int
    for i := 0; i < NUM_OF_SQUARES; i += 1 {
        rand_arr[i] = i
    }
    rand.shuffle(rand_arr[:])

    for i := 0; i < NUM_OF_SQUARES; i += 1 {
        visibility : bool
        if rand_arr[i] == 0 {
            visibility = false
        } else {
            visibility = true
        }
        pos := grid.cell_positions[i]
        square_render := Renderable{square_color_i, pos, grid.cell_size, grid.cell_size, visibility, true}
        square_render_i := insert_entity(square_render, &renderable.arr)
        square_entity := SquareEntity{square_render_i, rand_arr[i], {}, true}
        index := insert_entity(square_entity, &squares.arr)
    }
    
    for !rl.WindowShouldClose() {

        //Rendering
        rl.BeginDrawing()
        rl.ClearBackground({76, 53, 83, 255})

        camera := rl.Camera2D {
            zoom = ZOOM_MULTIPLIER
        }
        rl.BeginMode2D(camera)

        font := rl.GetFontDefault()

        //Draw Grid
        grid_render := retrieve_entity(grid.render_index, renderable.arr)
        grid_rec := renderable_to_rectangle(grid_render)
        rl.DrawRectangleRec(grid_rec, colors.arr[grid_render.color_index])

        //Draw Squares
        for s in squares.arr {
            if renderable.arr[s.render_index].visibility == true {
                square_render := retrieve_entity(s.render_index, renderable.arr)
                cstr_num := strings.clone_to_cstring(strconv.itoa(num_buf[:], s.number))
                if s.active {
                    rec := renderable_to_rectangle(square_render)
                    rl.DrawRectangleLinesEx(rec, SQUARE_OUTLINE_THICKNESS, SQUARE_COLOR)
                    DrawCenterText(font, rec, cstr_num, FONT_SIZE, FONT_SPACING, FONT_COLOR)
                    if ButtonClickRec(square_render, SQUARE_OUTLINE_THICKNESS) {
                        log.info(s, "Clicked")
                    }
                }
            }
        }

        rl.EndDrawing()

    }

    log.destroy_console_logger(context.logger)
}

ButtonClickRec :: proc(render: Renderable, line_thick: f32 = 0, mouse_click: rl.MouseButton = rl.MouseButton.LEFT) -> (bool) {
    mouse_pos := rl.GetMousePosition()
    mouse_x := mouse_pos[0]
    mouse_y := mouse_pos[1]
    lower_x := (render.x + line_thick) * ZOOM_MULTIPLIER
    upper_x := (render.x * ZOOM_MULTIPLIER) + ((render.width - line_thick) * ZOOM_MULTIPLIER)
    lower_y := (render.y + line_thick) * ZOOM_MULTIPLIER
    upper_y := (render.y * ZOOM_MULTIPLIER) + ((render.height - line_thick) * ZOOM_MULTIPLIER)
    if mouse_x >= lower_x && mouse_x <= upper_x && mouse_y >= lower_y && mouse_y <= upper_y && rl.IsMouseButtonPressed(mouse_click) == true {
        return true
    } else {
        return false
    }
}

DrawCenterText :: proc(font: rl.Font, rec: rl.Rectangle, text: cstring, fontSize, fontSpacing: f32, color: rl.Color = rl.BLACK) {
    fontWidth := rl.MeasureTextEx(font, text, fontSize, fontSpacing)
    center_x := rec.x + (rec.width/2)
    center_y := rec.y + (rec.height/2)
    offset_x := fontWidth[0]/2
    offset_y := fontWidth[1]/2
    center_x = center_x - offset_x
    center_y = center_y - offset_y
    v2 := rl.Vector2{center_x, center_y}
    rl.DrawTextEx(font, text, v2, fontSize, fontSpacing, color)
}

create_square_raw :: proc(x, y, w, h: f32, color: rl.Color, visiblity : bool = true, num : int, direction: DirectionSet, ) -> (SquareEntity) {
    color_index := insert_color(color, &colors.arr)
    render := Renderable{color_index, {x, y}, w, h, visiblity, true}
    render_index := insert_entity(render, &renderable.arr)
    
    square := SquareEntity{render_index, num, direction, true}
    square_index := insert_entity(square, &squares.arr)
    return square
}

create_square_from_struct :: proc(render: Renderable, square: SquareEntity, colors: ColorManager) -> (SquareEntity) {
    return create_square_raw(render.x, render.y, render.width, render.height, colors.arr[render.color_index], render.visibility, square.number, square.direction)
}

create_square :: proc{create_square_raw, create_square_from_struct}

renderable_to_rectangle :: proc(render: Renderable) -> (rl.Rectangle) {
    return rl.Rectangle{render.x, render.y, render.width, render.height}
}

create_grid_raw :: proc(x, y, width, height: f32, color: rl.Color, visibility: bool, column_size, row_size: int, cell_size: f32) -> (GridEntity) {
    color_i := insert_color(color, &colors.arr)
    render := Renderable{color_i, {x, y}, width, height, visibility, true}
    render_i := insert_entity(render, &renderable.arr)
    grid : GridEntity
    grid.render_index = render_i
    grid.column_size = column_size
    grid.row_size = row_size
    grid.cell_size = cell_size

    grid_y: f32 = 0
    for r := 0; r < row_size; r += 1 {
        grid_x : f32 = 0
        for c := 0; c < column_size; c += 1 {
            pos := Position{grid_x, grid_y}
            pos_i := append_soa(&grid.cell_positions, pos)
            grid_x += cell_size
        }
        grid_y += cell_size
    }
    return grid
}

create_grid_struct :: proc(render: Renderable, column_size, row_size: int, cell_size: f32) -> (GridEntity) {
    return create_grid_raw(render.x, render.y, render.width, render.height, retrieve_color(render.color_index, colors), render.visibility, column_size, row_size, cell_size)
}

create_grid :: proc{create_grid_raw, create_grid_struct}

insert_entity :: proc(val: $T, arr : ^#soa[dynamic]T) -> (index: int) {
    for i := 0; i < len(arr); i += 1 {
        if arr[i].active == false {
            arr[i] = val
            return i
        }
    }
    append_soa(arr, val)
    return len(arr) - 1
}

insert_color :: proc(val: rl.Color, arr: ^[dynamic]rl.Color) -> (index: int) {
    i, found := slice.linear_search(arr[:], val)
    if found {
        return i
    } else {
        append(arr, val)
        return len(arr) - 1
    }
}

retrieve_entity :: proc(index: int, arr: #soa[dynamic]$T) -> (T) {
    return arr[index]
}

retrieve_color_from_manager :: proc(index: int, colors: ColorManager) -> (rl.Color) {
    return retrieve_color_from_arr(index, colors.arr)
}

retrieve_color_from_arr :: proc(index: int, arr: [dynamic]rl.Color) -> (rl.Color) {
    return arr[index]
}

retrieve_color :: proc{retrieve_color_from_manager, retrieve_color_from_arr}

ColorManager :: struct {
    arr : [dynamic]rl.Color
}

Position :: struct {
    x, y: f32,
}

Renderable :: struct {
    color_index : int,
    using position: Position,
    width : f32,
    height : f32,
    visibility : bool,
    active : bool
}

RenderManager :: struct {
    arr : #soa[dynamic]Renderable
}

SquareEntity :: struct {
    render_index : int,
    number : int,
    direction : DirectionSet,
    active : bool
}

SquareManager :: struct {
    arr : #soa[dynamic]SquareEntity
}

GridEntity :: struct {
    render_index : int,
    column_size : int,
    row_size : int,
    cell_size : f32,
    cell_positions : #soa[dynamic]Position,
}

Direction :: enum{North, East, South, West}
DirectionSet :: bit_set[Direction]

