using GLVisualize, FileIO, Colors
using GLBooks, Reactive

GLBooks.init()

surf(i, N) = Float32[sin(x*i) * cos(y*i) for x = linspace(0, 2pi, N), y = linspace(0, 2pi, N)]

@block "Overview" begin
    loadasset("doge.png")
end

@block "Surface" begin
    s1 = slider(linspace(0.1f0, 2pi, 100), "surface function")
    drawpage(map(x-> surf(x, 128), s1), :surface)
end


@block "Surface with Image" begin
    video = loadasset("kittens-look.gif")
    play_s = playbutton("play")
    idx = foldp(1, fpswhen(play_s, 30.0)) do v0, t
        mod1(v0 + 1, size(video, 3))
    end
    imstream = map(i-> video[:, :, i], idx)
    s1 = slider(linspace(0.5f0, 2pi, 100), "surface function")
    drawpage(map(x-> surf(x, 128), s1), :surface, color = imstream)
end
