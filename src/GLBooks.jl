# Doesn't really make sense to precompile this!
__precompile__(false)
module GLBooks

using Colors, Images, Reactive, GeometryTypes, GLAbstraction, GLWindow
import GLVisualize
import GLVisualize: mm, layoutscreens, IRect, _view, visualize, glscreen
import GLVisualize: x_partition_abs, loadasset
import GLWindow: hide!, show!

const blocklist = Screen[]
const current_edit_screen = Ref{Screen}()
const current_view_screen = Ref{Screen}()
const current_widgetlist = Pair[]
edit_screen() = current_edit_screen[]
view_screen() = current_view_screen[]
widgetlist() = current_widgetlist
const _icon_size = Signal(10mm)
icon_size() = value(_icon_size)
empty!(blocklist)


parent_screen = glscreen(); @async GLWindow.waiting_renderloop(parent_screen)

function play_controls(screen)
    # load the icons
    paths = [
        "rewind_inactive.png", "rewind_active.png",
        "back_inactive.png", "back_active.png",
    ]
    imgs = map(paths) do path
        img = map(RGBA{U8}, loadasset(path))
        img, flipdim(img, 1)
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

navigation_visual, signals = play_controls(parent_screen)
_position = 1
for (i, block) in enumerate(blocklist)
    _position == i ? show!(block) : hide!(block)
end
step_page(dir) = max(mod1(dir, length(blocklist)), 1)
isdefined(:control_s) && foreach(close, control_s)
control_s = map(zip(signals, [-1, -1, 1, 1])) do sdir
    global _position
    s, dir = sdir
    map(s) do s
        if s && !isempty(blocklist)
            for (i, block) in enumerate(blocklist)
                _position == i ? show!(block) : hide!(block)
            end
            _position = step_page(_position + dir)
        else
            _position
        end
    end
end

function new_block()
    parent = Screen(parent_screen, hidden = Signal(false)) # copy screen, to make it easier to save!
    editarea, viewarea = x_partition_abs(parent.area, round(Int, 8.2 * icon_size()))
    edit_screen = Screen(
        parent, area = editarea,
    )
    view_screen = Screen(
        parent, area = viewarea, name = :GLBook
    )
    GLVisualize.add_screen(view_screen)
    edit_screen.stroke = (1, RGBA(0.9f0, 0.9f0, 0.9f0))
    current_edit_screen[] = edit_screen
    current_view_screen[] = view_screen
    empty!(current_widgetlist)
    push!(blocklist, parent)
    push!(current_widgetlist, :navigation => copy(navigation_visual))
    return view_screen
end



function playbutton(name)
    visual, signal = GLVisualize.playbutton(edit_screen())
    signal = map(!, signal)
    push!(widgetlist(), name => visual)
    signal
end
function playbutton(f, name)
    signal = playbutton(name)
    preserve(map(f, signal))
end

function slider(range, name; kw_args...)
    visual, signal = GLVisualize.labeled_slider(range, edit_screen(); kw_args...)
    push!(widgetlist(), name => visual)
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


macro block(window, block)
    last = gensym()
    esc(quote
        view_screen = GLBooks.new_block()


        $last = $(block)

        # TODO make this a GLVisualize function e.g., isvisualizable
        if applicable(GLVisualize._default, $last, GLAbstraction.Style{:default}(), Dict{Symbol,Any}())
            GLBooks.drawpage($last)
        end
        GLVisualize._view(GLVisualize.visualize(
            GLBooks.widgetlist(),
            text_scale = 4*GLVisualize.mm,
            width = 8*GLBooks.icon_size()
        ), GLBooks.edit_screen(), camera = :fixed_pixel)

        for cam in keys(view_screen.cameras)
            GLAbstraction.center!(view_screen, cam) # TODO, don't center corrupt bb's
        end
        $last
    end)
end


export @block, slider, drawpage, playbutton


end # module
