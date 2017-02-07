# Doesn't really make sense to precompile this!
__precompile__(false)
module GLBooks

# GL packages
import GLVisualize
using GeometryTypes, GLWindow

using Colors, Images, Reactive, FileIO
import GLVisualize: mm, layoutscreens, IRect, _view, visualize, glscreen
import GLVisualize: x_partition_abs, loadasset
import GLWindow: hide!, show!

const _icon_size = Signal(9mm)
icon_size() = value(_icon_size)

function play_controls(screen)
    # load the icons
    paths = [
        "rewind_inactive.png", "rewind_active.png",
        "back_inactive.png", "back_active.png",
    ]

    imgs = map(paths) do path
        img = convert(Matrix{RGBA{N0f8}}, loadasset(path))
        img, flipdim(img, 2)
    end
    # create buttons
    iconrect = IRect(0, 0, icon_size(), icon_size())
    buttons = [
        GLVisualize.toggle_button(imgs[1][1], imgs[2][1], screen; primitive = iconrect),
        GLVisualize.button(imgs[3][1], screen; primitive = iconrect),
        GLVisualize.button(imgs[3][2], screen; primitive = iconrect),
        GLVisualize.toggle_button(imgs[1][2], imgs[2][2], screen; primitive = iconrect),
    ]
    visual = visualize(
        map(first, buttons), direction = 1
    )
    signals = map(last, buttons)
    visual, signals
end

global edit_screen, view_screen, widgetlist, new_block, init

global _block_position = 0
const navigation = []
const parent_screen = Ref{Screen}()
const blocklist = Screen[]
const current_widgetlist = []

edit_screen() = blocklist[_block_position].children[1]
view_screen() = blocklist[_block_position].children[2]
widgetlist() = current_widgetlist[_block_position]

step_page(dir) = max(mod1(dir, length(blocklist)), 1)

function handle_drop(files::Vector{String})
    for f in files
        try
            drawpage(load(f))
        catch e
            warn(e)
        end
    end
end


function init()
    global _block_position
    _block_position = 0
    parent_screen[] = glscreen()
    @async GLWindow.renderloop(parent_screen[])
    empty!(blocklist)
    for list in current_widgetlist
        for (nameobj, s) in list
            close(s, false)
        end
    end
    empty!(current_widgetlist)
    if !isempty(navigation) # old signals in there
        for s in navigation[end]
            close(s, false) # close old signal
        end
        empty!(navigation)
    end
    push!(navigation, play_controls(parent_screen[])...)
    s1 = map(handle_drop, parent_screen[].inputs[:dropped_files])
    position = 1
    control_s = map(zip(navigation[2], [-1, -1, 1, 1])) do sdir
        s, dir = sdir
        map(s, init = nothing) do s
            position = if s && !isempty(blocklist)
                for (i, block) in enumerate(blocklist)
                    position == i ? show!(block) : hide!(block)
                end
                step_page(position + dir)
            else
                position
            end
            _block_position = position
            nothing
        end
    end
    push!(control_s, s1)
    push!(navigation, control_s)
end
function new_block()
    global _block_position
    _block_position += 1
    hidden = !isempty(blocklist) # only show first block
    parent = Screen(parent_screen[], hidden = Signal(hidden)) # copy screen, to make it easier to save!
    editarea, viewarea = x_partition_abs(parent.area, round(Int, 8 * icon_size()))
    edit_screen = Screen(parent, area = editarea)
    view_screen = Screen(parent, area = viewarea, name = :GLBook)
    GLVisualize.add_screen(view_screen) # make screen available
    edit_screen.stroke = (1, RGBA(0.9f0, 0.9f0, 0.9f0))
    push!(current_widgetlist, Any[("navigation" => copy(navigation[1]), Signal(0))])
    push!(blocklist, parent)
    return view_screen
end


function playbutton(name)
    visual, signal = GLVisualize.playbutton(edit_screen())
    signal = map(!, signal)
    push!(widgetlist(), (name => visual, signal))
    signal
end
function playbutton(f, name)
    signal = playbutton(name)
    preserve(map(f, signal))
end

function slider(range, name; slider_length = 5*icon_size(), kw_args...)
    visual, signal = GLVisualize.labeled_slider(
        range, edit_screen(); slider_length = slider_length, kw_args...
    )
    push!(widgetlist(), (name => visual, signal))
    signal
end
function slider(f::Function, range, name; kw_args...)
    signal = slider(range, name; kw_args...)
    s2 = map(f, signal)
    s2
end

function drawpage(x, style = :default; kw_args...)
    _view(visualize(x, style; kw_args...), view_screen())
end


macro block(title, block)
    last, view_screen = gensym(), gensym()
    esc(quote
        let
            $view_screen = GLBooks.new_block()


            $last = $(block)

            push!(GLBooks.widgetlist(), ("title:" => visualize($title), Signal(0)))

            # TODO make this a GLVisualize function e.g., isvisualizable
            if applicable(GLVisualize._default, $last, GLAbstraction.Style{:default}(), Dict{Symbol,Any}())
                GLBooks.drawpage($last)
            end
            widgets = convert(Vector{Pair}, map(first, GLBooks.widgetlist()))
            GLVisualize._view(GLVisualize.visualize(
                widgets,
                text_scale = 4*GLVisualize.mm,
                width = 8*GLBooks.icon_size()
            ), GLBooks.edit_screen(), camera = :fixed_pixel)

            for cam in keys($view_screen.cameras)
                GLAbstraction.center!($view_screen, cam) # TODO, don't center corrupt bb's
            end
            $last
        end
    end)
end


export @block, slider, drawpage, playbutton


end # module
