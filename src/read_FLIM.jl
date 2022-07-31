function read_flim(filename; data_channel=2, marker_channel_y = nothing, marker_channel_z = nothing, bins=128, dtype=UInt32)
    q = read_ptu(filename);
    if length(q) != 3
        error("This data does not contain time tags")
        return nothing
    end
    channels, time_tags, dtimes = q

    if isnothing(marker_channel_y)
        println("No 'marker_channel_y' provided. Calculating statistics.... be patient.")
        chans = zeros(Int32, 31)
        chans = reduce((x,y) -> x .+ (y.==(0:size(chans,1)-1)), channels, init=chans)
        for n=1:size(chans,1)
            if chans[n] !== zero(Int32)
                if n>=15
                    println("marker $n has $(chans[n]) tags.")
                else
                    println("channel $n has $(chans[n]) counts.")
                end
            end
        end
        println("Chose one maker as 'marker_channel_y' to process the data. Optionally also 'marker_channel_z' can be supplied.")
        return
    end
    data_channel -= 1
    println("Found $(sum(channels .== data_channel)) events.")
    marker_channel_y -= 1
    N_lines = sum(channels .== marker_channel_y)
    if N_lines == 0
        error("The line channel $(marker_channel_y+1) does not contain events.")
    end
    nx = ny = N_lines
    N_frames = let
        if isnothing(marker_channel_z)
            1
        else
            marker_channel_z -= 1
            max(sum(channels .== marker_channel_z),1)
        end
    end
    nz = N_frames
    T_max = maximum(dtimes)
    T_bin = 1 + floor(Int32,Float32(T_max) /bins)
    @show sx = nx
    @show sy = ny
    @show sz = nz
    flim_img = zeros(dtype, (sx,sy,sz,bins))
    x=y=z=1
    t_start = time_tags[1]
    # look for the first two line tags
    idx_t1 = findfirst((x)->x==marker_channel_y, channels)
    idx_t2 = findnext((x)->x==marker_channel_y, channels, idx_t1+1)
    idx_t3 = findnext((x)->x==marker_channel_y, channels, idx_t2+1)
    @show delta_t1 = (time_tags[idx_t2]-time_tags[idx_t1])/sx
    @show delta_t2 = (time_tags[idx_t3]-time_tags[idx_t2])/sx
    return
    @showprogress for (ch, tt, dt) in zip(channels, time_tags, dtimes)
        x = min(1+floor(Int32,(tt - t_start)/delta_t),sx)
        if (ch == data_channel) # sort into FLIM bin
            bin = 1+floor(Int32,dt/T_bin)
            flim_img[x,y,z,bin] += 1
        elseif (ch == marker_channel_y) # new line
            y += 1
            t_start = tt
            if y > ny
                @warn("more lines $(N_lines) in data than ny $(ny). stopping")
                return flim_img
            end
        elseif !isnothing(marker_channel_z) && (ch == marker_channel_z) # new frame
            z += 1
            y = 0
            t_start = tt
        end
    end

    return flim_img
end

function mirror_bidirectional(img, myshift=-55.0)
    myeven = @view img[:,1:2:end,:,:];
    myeven .= myeven[end:-1:1,:,:,:]
    myeven .= shift(myeven, (myshift,0.0,0.0,0.0,0.0));
end