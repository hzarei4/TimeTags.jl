using TimeTags
using NPZ

dat1, dat2 = TimeTags.read_ptu(raw"D:\Hossein\Programming\Julia\TestBeds\SaeedData\DoubleDefect_5_633SP.ptu")

npzwrite("DoubleDefect_5_633SP.npz", Dict("x" => dat1, "y" => dat2));
