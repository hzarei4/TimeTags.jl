function process_flim(channels, time_tags, dtimes; sx = 350, sy = 201, data_channel=2, marker_channel_y = nothing, marker_channel_z = nothing, bins=128, is_bidirectional=true, tag_offset=0.0) 
    data_channel -= 1
    println("Found $(sum(channels .== data_channel)) events.")
    marker_channel_y -= 1
    # N_lines = Int64(sum(channels .== marker_channel_y))
    # if N_lines == 0
    #     error("The line channel $(marker_channel_y+1) does not contain events.")
    # end
    # nx = sx
    # ny = N_lines
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
    @show T_bin = 1 + floor(Int32,Float32(T_max) /bins)
    # sy = ny + 1
    @show sy
    sz = nz
    flim_img = zeros(UInt32, (sx,sy,sz,bins))
    x=y=z=1
    t_start = time_tags[1]
    # look for the first two line tags
    idx_t1 = findfirst((x)->x==marker_channel_y, channels)
    idx_t2 = findnext((x)->x==marker_channel_y, channels, idx_t1+1)
    #idx_t3 = findnext((x)->x==marker_channel_y, channels, idx_t2+1)
    @show delta_t = (time_tags[idx_t2]-time_tags[idx_t1])/sx
    # @show delta_t2 = (time_tags[idx_t3]-time_tags[idx_t2])/sx
    n=1
    y = 1
    my_y = 1
    # @showprogress for (ch,tt) in zip(channels, time_tags)  #(ch, tt, dt) in zip(channels, time_tags, dtimes)
    #     flim_img[1,1,1,1] = one(UInt32)
    # end
    # return flim_img
    @showprogress for (ch,tt) in zip(channels, time_tags)  #(ch, tt, dt) in zip(channels, time_tags, dtimes)
        if is_bidirectional
            if iseven(y)
                x = 1 + floor(Int32,(tt - t_start)/delta_t + tag_offset)
            else
                x = sx - floor(Int32,(tt - t_start)/delta_t + tag_offset)
            end
            # implement a wrap-around
            if x < 1
                my_y = min(y + 1, sy)
                x = 1 - x
            elseif x > sx
                x = sx - (x - sx)
                my_y = max(y - 1, 1)
            else
                my_y = y
            end
            x = clamp(x,1,sx)
            my_y = clamp(my_y,1,sy)
        else
            my_y = clamp(y,1,sy)
            x = clamp(1 + floor(Int32,(tt - t_start)/delta_t), 1, sx)
        end
        if (ch == data_channel) # sort into FLIM bin
            dt = dtimes[n]
            bin = 1 + floor(Int32,dt/T_bin)
            # flim_img[1,1,1,1] = 1 # += one(dtype)
            flim_img[x,my_y,z,bin] += one(UInt32)
        elseif (ch == marker_channel_y) # new line
            y += 1
            t_start = time_tags[n] # tt
            if y > sy
                @warn("more lines $(N_lines) in data than ny $(ny). stopping")
            end
        elseif !isnothing(marker_channel_z) && (ch == marker_channel_z) # new frame
            z += 1
            y = 1
            t_start = tt
        end
        n += 1
    end

    return flim_img
end

function read_flim(filename; sx = 350, sy = nothing, data_channel=2, marker_channel_y = nothing, marker_channel_z = nothing, bins=128, dtype=UInt16, is_bidirectional=true, tag_offset=0.0)
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
    N_lines = Int64(sum(channels .== marker_channel_y - 1))
    if N_lines == 0
        error("The line channel $(marker_channel_y+1) does not contain events.")
    end
    if isnothing(sy)
        sy = N_lines + 2 # to account for the extra bits at the beginning and end
    end

    @time res = process_flim(channels, time_tags, dtimes; sx = sx, sy = sy, data_channel=data_channel, marker_channel_y = marker_channel_y, marker_channel_z = marker_channel_z, bins=bins, is_bidirectional=is_bidirectional, tag_offset=tag_offset)
    return res
end

function mirror_bidirectional(img, myshift=-55.0)
    myeven = @view img[:,1:2:end,:,:];
    myeven .= myeven[end:-1:1,:,:,:]
    myeven .= shift(myeven, (myshift,0.0,0.0,0.0,0.0));
end

function get_interlace(img)
    simg = sum(img,dims=(3,4))[:,:,1,1]
    sy = (size(simg,2)÷2)*2
    img_odd = simg[:,1:2:sy]
    img_even = simg[:,2:2:sy]
    myshift = find_shift_iter(img_even, img_odd)
    @printf("add argument: ', tag_offset = %.3f'\n", -myshift[1] / 2)
    return -myshift[1] / 2
end

function get_t_mean(img)
    pos_h = reorient(1:size(img,4), 4)
    simg = sum(img, dims=4)[:,:,:,1]    
    return sum(img .* pos_h, dims=4)[:,:,:,1] ./ simg
end
