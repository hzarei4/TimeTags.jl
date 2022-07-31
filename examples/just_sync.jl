using TimeTags, Plots, Statistics

channels, time_tags = read_ptu(raw"firstexp2s.ptu");
overflows = time_tags[channels .== 255]
time_tags = time_tags[channels .!= 255]

N_max = 2000
rel_time = (time_tags[2:N_max].-time_tags[1:N_max-1]) 

plot(rel_time .* get_time_conversion(), ylabel="Time Difference / s", xlabel="Event")


rel_time = (time_tags[2:end].-time_tags[1:end-1]) 
histogram(rel_time.* get_time_conversion(), ylabel="Events", xlabel="Time Difference / s")

std(rel_time.* get_time_conversion())

###

channels, time_tags, dtimes = read_ptu(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\DaisyPollen_cells_FLIM.ptu");
channels, time_tags, dtimes = read_ptu(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\CENP-labelled_cells_for_FRET.ptu");
channels, time_tags, dtimes = read_ptu(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\FRET_GFP_and_mRFP.ptu");
overflows = time_tags[channels .== 255]
time_tags = time_tags[channels .!= 255]

N_max = 2000
rel_time = (time_tags[2:N_max].-time_tags[1:N_max-1]) 

plot(time_tags[1:10:600000])
###
q = read_flim(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\DaisyPollen_cells_FLIM.ptu", marker_channel_y=21);
# 200x200

q = read_flim(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\FRET_GFP_and_mRFP.ptu");
# 256x256

q = read_flim(raw"C:\NoBackup\Data\FLIM\FRET_GFP_and_mRFP\CENP-labelled_cells_for_FRET.ptu");
# 512x512

