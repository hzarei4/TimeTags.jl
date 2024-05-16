using TimeTags, View5D

function main()
    q = read_flim(raw"D:\data\FLIM_data\LSM_15.pt3",  sx = 512, data_channel=2, marker_channel_y=18, is_bidirectional=false);
end
