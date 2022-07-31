"""
    Tools for reading an processing PicoQuant `.ptu` time-tagged (list-mode) time correlated single photon counting (TCSPC) data.

    This code is based on the Matlab version of a file that read .ptu data:
    https://github.com/PicoQuant/PicoQuant-Time-Tagged-File-Format-Demos/tree/master/PTU/MatLab/
    Note that it (like the Matlab version) uses eval commands, which makes it dangerous for code injection.

"""
module TimeTags

using Printf, ProgressMeter, FindShift, NDTools
export read_ptu, get_time_conversion, read_flim, get_interlace, get_t_mean

include("read_ptu.jl")
include("read_FLIM.jl")
end # module
