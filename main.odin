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

//Globals
squares : SquareManager
positions : PositionManager
dimensions : DimensionManager
numbers : NumberManager
vis_man : VisibilityManager
colors : ColorManager

//Buffers
num_buf : [4]byte


main :: proc() {
    context.logger = log.create_console_logger()
    log.info("Program started")

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "15 Puzzle")

    grid : GridEntity
    grid = create_grid(0, 0, CELL_SIZE * COLUMN_SIZE, CELL_SIZE * ROW_SIZE, NUM_OF_SQUARES, CELL_SIZE, COLUMN_SIZE, ROW_SIZE, GRID_COLOR)

    rand_arr : [NUM_OF_SQUARES]int

    for i := 0; i < NUM_OF_SQUARES; i += 1 {
        rand_arr[i] = i
    }
    rand.shuffle(rand_arr[:])

    for i := 0; i < len(rand_arr); i += 1 {
        pos := retrieve_entity(grid.cell_position_index[i], positions.arr)
        dim := Dimension{CELL_SIZE, CELL_SIZE, true}
        num := SquareNumber{rand_arr[i], true}
        square := create_square(pos, dim, num, SQUARE_COLOR, {true, true})
        index := insert_entity(square, &squares.arr)
    }

    s := squares.arr[0]
    num := retrieve_entity(s.number_index, numbers.arr)
    cstr_num := strings.clone_to_cstring(strconv.itoa(num_buf[:], num.num))
    rec := square_to_rec(s)
    
    for !rl.WindowShouldClose() {

        //Rendering
        rl.BeginDrawing()
        rl.ClearBackground({76, 53, 83, 255})

        camera := rl.Camera2D {
            zoom = ZOOM_MULTIPLIER
        }
        rl.BeginMode2D(camera)

        grid_pos := retrieve_entity(grid.position_index, positions.arr)
        grid_dim := retrieve_entity(grid.dimension_index, dimensions.arr)
        grid_color := retrieve_color(grid.color_index, colors)
        grid_rec := rl.Rectangle{grid_pos.x, grid_pos.y, grid_dim.width, grid_dim.length}
        rl.DrawRectangleRec(grid_rec, grid_color)

        for s in squares.arr {
            pos := retrieve_entity(s.position_index, positions.arr)
            dim := retrieve_entity(s.dimension_index, dimensions.arr)
            num := retrieve_entity(s.number_index, numbers.arr)
            // cstr_num := strings.clone_to_cstring(strconv.itoa(num_buf[:], num.num))
            rec := rl.Rectangle{f32(pos.x), f32(pos.y), f32(dim.width), f32(dim.length)}
            rl.DrawRectangleLinesEx(rec, SQUARE_OUTLINE_THICKNESS, SQUARE_COLOR)
            if ButtonClickRec(rec, SQUARE_OUTLINE_THICKNESS) {
                log.info(num, "Clicked")
            }

        }

        rl.EndDrawing()

    }

    log.destroy_console_logger(context.logger)
}

ButtonClickRec :: proc(rec: rl.Rectangle, line_thick: f32 = 0, mouse_click: rl.MouseButton = rl.MouseButton.LEFT) -> (bool) {
    mouse_pos := rl.GetMousePosition()
    mouse_x := mouse_pos[0]
    mouse_y := mouse_pos[1]
    lower_x := (rec.x + line_thick) * ZOOM_MULTIPLIER
    upper_x := (rec.x * ZOOM_MULTIPLIER) + ((rec.width - line_thick) * ZOOM_MULTIPLIER)
    lower_y := (rec.y + line_thick) * ZOOM_MULTIPLIER
    upper_y := (rec.y * ZOOM_MULTIPLIER) + ((rec.height - line_thick) * ZOOM_MULTIPLIER)
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

create_square_raw :: proc(x, y, l, w: f32, num : int, color: rl.Color, state : bool = true) -> (SquareEntity) {
    pos := Position{x, y, true}
    dim := Dimension{l, w, true}
    center := Position{x+(w/2), y+(l/2), true}
    sqr_num := SquareNumber{num, true}
    vis := Visibility{state, true}
    pos_index := insert_entity(pos, &positions.arr)
    dim_index := insert_entity(dim, &dimensions.arr)
    center_index := insert_entity(center, &positions.arr)
    num_index := insert_entity(sqr_num, &numbers.arr)
    vis_index := insert_entity(vis, &vis_man.arr)
    color_index := insert_color(color, &colors.arr)
    square := SquareEntity{pos_index, dim_index, center_index, num_index, vis_index, color_index, true}
    return square
}

create_square_from_struct :: proc(pos : Position, dim : Dimension, num : SquareNumber, color: rl.Color, vis : Visibility) -> (SquareEntity) {
    return create_square_raw(pos.x, pos.y, dim.length, dim.width, num.num, color, vis.state)
}

create_square :: proc{create_square_raw, create_square_from_struct}

square_to_rec :: proc(square: SquareEntity) -> (rl.Rectangle) {
    pos := retrieve_entity(square.position_index, positions.arr)
    dim := retrieve_entity(square.dimension_index, dimensions.arr)
    rec := rl.Rectangle{f32(pos.x), f32(pos.y), f32(dim.width), f32(dim.length)}
    return rec
}

create_grid_raw :: proc(grid_x, grid_y, grid_l, grid_w: f32, cell_num, cell_size, column_size, row_size: int, grid_color: rl.Color) -> (GridEntity) {
    grid_pos := Position{grid_x, grid_y, true}
    grid_dim := Dimension{grid_l, grid_w, true}
    grid_pos_index := insert_entity(grid_pos, &positions.arr)
    grid_dim_index := insert_entity(grid_dim, &dimensions.arr)
    grid_color_index := insert_color(grid_color, &colors.arr)
    grid : GridEntity
    grid.position_index = grid_pos_index
    grid.dimension_index = grid_dim_index
    grid.number_of_cells = cell_num
    grid.color_index = grid_color_index

    y: f32 = 0
    for r := 0; r < row_size; r += 1 {
        x : f32 = 0
        for c := 0; c < column_size; c += 1 {
            pos := Position{x, y, true}
            visiblity := false
            pos_index := insert_entity(pos, &positions.arr)
            append(&grid.cell_position_index, pos_index)
            x += f32(cell_size)
        }
        y += f32(cell_size)
    }
    return grid
}

create_grid_struct :: proc(pos: Position, dim: Dimension, cell_num, cell_size, column_size, row_size: int, color: rl.Color) -> (GridEntity) {
    return create_grid_raw(pos.x, pos.y, dim.length, dim.width, cell_num, cell_size, column_size, row_size, color)
}

create_grid :: proc{create_grid_raw, create_grid_struct}

populate_grid :: proc(grid : GridEntity) {
    for s in grid.cell_position_index {

    }
}

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

SquareNumber :: struct {
    num : int,
    active : bool
}

NumberManager :: struct {
    arr : #soa[dynamic]SquareNumber
}

Position :: struct {
    x : f32,
    y : f32,
    active : bool
}

PositionManager :: struct {
    arr : #soa[dynamic]Position
}

Dimension :: struct {
    length : f32,
    width : f32,
    active : bool
}

DimensionManager :: struct {
    arr : #soa[dynamic]Dimension
}

Visibility :: struct {
    state : bool,
    active : bool
}

VisibilityManager :: struct {
    arr : #soa[dynamic]Visibility
}

SquareEntity :: struct {
    position_index : int,
    dimension_index : int,
    center_index : int,
    number_index : int,
    visibility_index : int,
    color_index : int,
    active : bool
}

SquareManager :: struct {
    arr : #soa[dynamic]SquareEntity
}

GridEntity :: struct {
    position_index : int,
    dimension_index : int,
    number_of_cells : int,
    color_index : int,
    cell_position_index : [dynamic]int,
}

WindowEntity :: struct {

}

