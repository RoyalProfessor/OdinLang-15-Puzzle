package main

//imports
import rl "vendor:raylib"
import "core:slice"
import "core:math/rand"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:log"
import "core:mem"
import "base:runtime"

// Constants
WINDOW_WIDTH :: 1050
WINDOW_HEIGHT :: 830
CELL_SIZE :: 200
GUI_SCALING :: 10
SQUARE_SPACING :: f32(1 * GUI_SCALING)
SQUARE_OUTLINE :: f32(.2 * GUI_SCALING)
GRID_OUTLINE :: f32(.15 * GUI_SCALING)
CANVAS_WIDTH :: CELL_SIZE * COLUMN_SIZE
CANVAS_HEIGHT :: CELL_SIZE * ROW_SIZE
CANVAS_AREA :: CANVAS_WIDTH * CANVAS_HEIGHT
LEFT_ALIGNMENT :: f32(-110)
ZOOM_MULTIPLIER :: 1 //WINDOW_SIZE / CANVAS_WIDTH
NUM_OF_SQUARES :: ROW_SIZE * COLUMN_SIZE
GRID_POSITION :: Position{0, 0}
ROW_SIZE :: 4
COLUMN_SIZE :: 4
SQUARE_COLOR :: rl.Color{173,216,230,255}
CORRECT_SQUARE_COLOR :: rl.GOLD
GRID_COLOR :: rl.Color{212,188,114,255}
BACKGROUND_COLOR :: rl.Color{132, 110, 40, 255}
OUTLINE_COLOR :: rl.BLACK
FONT_SIZE :: CELL_SIZE
FONT_SPACING :: f32(1 * GUI_SCALING)
FONT_COLOR :: rl.BLACK
OUTLINE_LAYER :: 0
SQUARE_LAYER :: 1

//Globals
squares : SquareManager
zero_index : int
win : bool
solvable : bool

//Buffers
num_buf : [8]byte


main :: proc() {

    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                for _, entry in track.allocation_map {
                    fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
                }
            }
            if len(track.bad_free_array) > 0 {
                for entry in track.bad_free_array {
                    fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }

    context.logger = log.create_console_logger()

    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "15 Puzzle")
    log.info("Program started")

    window_center := find_center(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
    window_center_offset := find_center_offset(CANVAS_WIDTH + SQUARE_SPACING, CANVAS_HEIGHT + SQUARE_SPACING, window_center)
    window_center_offset.x += LEFT_ALIGNMENT
    grid_render := Renderable{GRID_COLOR, window_center_offset, CANVAS_WIDTH + SQUARE_SPACING, CANVAS_HEIGHT + SQUARE_SPACING, true}

    log.info(grid_render)

    grid : GridEntity
    grid = create_grid(grid_render, COLUMN_SIZE, ROW_SIZE, CELL_SIZE)

    //Creates array of numbers.
    rand_arr : [NUM_OF_SQUARES]int
    for i := 0; i < NUM_OF_SQUARES; i += 1 {
        rand_arr[i] = i
    }

    //Shuffles numbers until valid state.
    for solvable == false {
        rand.shuffle(rand_arr[:])
        solvable = check_solvability(COLUMN_SIZE, rand_arr[:])
    }

    //Create Squares for each cell position and number
    for i := 0; i < NUM_OF_SQUARES; i += 1 {
        pos := grid.cell_positions[i]
        pos.x += SQUARE_SPACING
        pos.y += SQUARE_SPACING
        width := grid.cell_size - SQUARE_SPACING
        height := grid.cell_size - SQUARE_SPACING
        direction := DirectionSet{}
        square := create_square(pos.x, pos.y, width, height, SQUARE_COLOR, true, rand_arr[i], direction)
        index := insert_entity_soa(square, &squares.arr)
    }
    
    for !rl.WindowShouldClose() {

        // Reset Square Visibility and Direction.
        for &s in squares.arr {
            s.render.visibility = true
            s.data.direction = {}
        }

        // Assign directions and visibility for squares based on zero number location.
        zero_index = assign_directions(grid, &squares)
        squares.arr[zero_index].render.visibility = false

        // Rendering Start
        rl.BeginDrawing()
        rl.ClearBackground(BACKGROUND_COLOR)

        camera := rl.Camera2D {
            zoom = ZOOM_MULTIPLIER
        }
        rl.BeginMode2D(camera)

        font := rl.GetFontDefault()

        // Draw Grid.
        grid_rec := renderable_to_rectangle(grid.render)
        rl.DrawRectangleRec(grid_rec, grid.render.color)
        rl.DrawRectangleLinesEx(grid_rec, GRID_OUTLINE, rl.BLACK)

        // Draw Squares, Square Text, and register Square Clicks.
        for i := 0; i < len(squares.arr); i += 1 {
            if squares.arr[i].render.visibility {
                s := squares.arr[i]
                rec := renderable_to_rectangle(s.render)
                cstr_num := strings.clone_to_cstring(strconv.itoa(num_buf[:], s.data.number))
                color : rl.Color
                if i + 1 == s.data.number {
                    color = CORRECT_SQUARE_COLOR
                } else {
                    color = s.render.color
                }
                rl.DrawRectangleRec(rec, color)
                rl.DrawRectangleLinesEx(rec, SQUARE_OUTLINE, OUTLINE_COLOR)
                draw_center_text(font, rec, cstr_num, FONT_SIZE, FONT_SPACING, FONT_COLOR)
                if button_click_render(s.render, ZOOM_MULTIPLIER) && win == false {
                    if s.data.direction != {} {
                        swap_numbers_soa(zero_index, i, &squares.arr)
                    }
                }
            }
        }

        // Checks win condition
        win = check_win_condition(NUM_OF_SQUARES - 1, squares)
        if win {
            rec := renderable_to_rectangle(grid.render)
            rl.DrawRectangleRec(rec, GRID_COLOR)
            draw_center_text(font, rec, "You won!", FONT_SIZE, FONT_SPACING)
        }

        rl.EndDrawing()

        free_all(context.temp_allocator)
    }

    delete(squares.arr)
    log.destroy_console_logger(context.logger)
}

button_click_render :: proc(render: Renderable, zoom: f32, line_thick: f32 = 0, mouse_click: rl.MouseButton = rl.MouseButton.LEFT) -> (bool) {
    mouse_pos := rl.GetMousePosition()
    mouse_x := mouse_pos[0]
    mouse_y := mouse_pos[1]
    lower_x := (render.x + line_thick) * zoom
    upper_x := (render.x * zoom) + ((render.width - line_thick) * zoom)
    lower_y := (render.y + line_thick) * zoom
    upper_y := (render.y * zoom) + ((render.height - line_thick) * zoom)
    if mouse_x >= lower_x && mouse_x <= upper_x && mouse_y >= lower_y && mouse_y <= upper_y && rl.IsMouseButtonPressed(mouse_click) == true {
        return true
    }
    return false
}

draw_center_text :: proc(font: rl.Font, rec: rl.Rectangle, text: cstring, fontSize, fontSpacing: f32, color: rl.Color = rl.BLACK) {
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

check_solvability :: proc(n: int, arr: []int) -> (bool) {
    counter, zero_index : int
    n_even, zero_even, inversion_even, found : bool
    n_even = n % 2 == 0

    for i := 0; i < len(arr); i += 1 {
        if arr[i] != 0 {
            counter += count_inversion(arr[i], arr[i+1:])
        }
    }
    inversion_even = counter % 2 == 0

    if n_even == false {
        return counter % 2 == 0
    } else {
        zero_index, found = slice.linear_search(arr, 0)
        zero_even = (n - (zero_index/n)) % 2 != 0
        return zero_even != inversion_even
    }
}

count_inversion :: proc(number: int, arr: []int) -> (int) {
    counter : int
    for i in arr {
        if number > i {
            counter += 1
        }
    }
    return counter
}

check_win_condition :: proc(num_of_squares: int, squares: SquareManager) -> (bool) {
    counter : int
    for i := 0; i < len(squares.arr); i += 1 {
        if i + 1 == squares.arr[i].data.number {
            counter += 1
        }
    }
    if counter == num_of_squares {
        return true
    }
    return false
}

find_center_pos :: proc(x, y, width, height: f32) -> (center: Position) {
    center.x = x + (width/2)
    center.y = y + (height/2)
    return
}

find_center_render :: proc(render: Renderable) -> (pos: Position) {
    return find_center_pos(render.x, render.y, render.width, render.height)
}

find_center :: proc{find_center_pos, find_center_render}

find_center_offset :: proc(width, height: f32, center: Position) -> (offset: Position) {
    offset.x = center.x - (width/2)
    offset.y = center.y - (height/2)
    return
}

create_square_raw :: proc(x, y, w, h: f32, color: rl.Color, visiblity : bool = true, num : int, direction: DirectionSet) -> (SquareEntity) {
    render := Renderable{color, {x, y}, w, h, visiblity}
    data := SquareData{num, direction}
    square := SquareEntity{render, data}
    return square
}

create_square_from_struct :: proc(render: Renderable, square: SquareEntity) -> (SquareEntity) {
    return create_square_raw(render.x, render.y, render.width, render.height, render.color, render.visibility, square.data.number, square.data.direction)
}

create_square :: proc{create_square_raw, create_square_from_struct}

renderable_to_rectangle :: proc(render: Renderable) -> (rl.Rectangle) {
    return rl.Rectangle{render.x, render.y, render.width, render.height}
}

create_grid_raw :: proc(x, y, width, height: f32, color: rl.Color, visibility: bool, column_size, row_size: int, cell_size: f32) -> (GridEntity) {
    render := Renderable{color, {x, y}, width, height, visibility}
    grid : GridEntity
    grid.render = render
    grid.column_size = column_size
    grid.row_size = row_size
    grid.cell_size = cell_size

    grid_y: f32 = y
    for r := 0; r < row_size; r += 1 {
        grid_x : f32 = x
        for c := 0; c < column_size; c += 1 {
            pos := Position{grid_x, grid_y}
            pos_i := append(&grid.cell_positions, pos)
            grid_x += cell_size
        }
        grid_y += cell_size
    }
    return grid
}

create_grid_struct :: proc(render: Renderable, column_size, row_size: int, cell_size: f32) -> (GridEntity) {
    return create_grid_raw(render.x, render.y, render.width, render.height, render.color, render.visibility, column_size, row_size, cell_size)
}

create_grid :: proc{create_grid_raw, create_grid_struct}

insert_entity_soa :: proc(val: $T, arr : ^#soa[dynamic]T) -> (index: int) {
    append_soa(arr, val)
    return len(arr) - 1
}

assign_directions :: proc(grid: GridEntity, squares: ^SquareManager) -> (int) {
    index : int
    for i := 0; i < len(squares.arr); i += 1 {
        if squares.arr[i].data.number == 0 {
            index = i
        }
    }
    
    north, south, east, west : int
    north = index - grid.column_size
    south = index + grid.column_size
    east = index + 1
    west = index - 1

    if north >= 0 {
        s := &squares.arr[north]
        s.data.direction += {.South}
    }
    if south <= len(squares.arr) - 1 {
        s := &squares.arr[south]
        s.data.direction += {.North}
    }
    if index % grid.column_size != grid.column_size - 1 {
        s := &squares.arr[east]
        s.data.direction += {.West}
    }
    if index % grid.column_size != 0 {
        s := &squares.arr[west]
        s.data.direction += {.East}
    }
    return index
}

swap_numbers_soa :: proc(zero, target: int, arr: ^#soa[dynamic]$T) {
    arr[zero].data.number, arr[target].data.number = arr[target].data.number, arr[zero].data.number
}

retrieve_entity_soa :: proc(index: int, arr: #soa[dynamic]$T) -> (T) {
    return arr[index]
}

Position :: struct {
    x, y: f32,
}

Renderable :: struct {
    color : rl.Color,
    using position: Position,
    width : f32,
    height : f32,
    visibility : bool,
}

RenderManager :: struct {
    arr : [dynamic]Renderable
}

SquareData :: struct {
    number : int,
    direction : DirectionSet
}

SquareEntity :: struct {
    render : Renderable,
    data : SquareData
}

SquareManager :: struct {
    arr : #soa[dynamic]SquareEntity
}

GridEntity :: struct {
    render : Renderable,
    column_size : int,
    row_size : int,
    cell_size : f32,
    cell_positions : [dynamic]Position,
}

RenderOrderManager :: struct {
    arr : [dynamic]RenderManager
}

Direction :: enum {North, East, South, West}
DirectionSet :: bit_set[Direction]

