using TimeTags, Plots

channels, time_tags = read_ptu(raw"firstexp2s.ptu");
overflows = time_tags[channels .== 255]
time_tags = time_tags[channels .!= 255]

N_max = 2000
rel_time = (time_tags[2:N_max].-time_tags[1:N_max-1]) 

plot(rel_time .* get_time_conversion(), ylabel="Time Difference / s", xlabel="Event")

