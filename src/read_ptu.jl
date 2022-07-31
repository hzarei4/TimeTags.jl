
"""
    read_ptu(full_filename) # Read PicoQuant Unified TTTR Files

    reads a .ptu file from `full_filename`.
    The time-tagged data is retuned as a tuble of two arrays.
    A `UInt8` array of the channels and a `Float64` array of the timings.
    The environment needs the packages `Printf` and `ProgressMeter` installed (`]add Prinf, ProgressMeter`).
# Arguments
+ full_filename:    full filename including path and file extension `.ptu` of the file to process
"""
function read_ptu(full_filename) # Read PicoQuant Unified TTTR Files
    # This is demo code. Use at your own risk. No warranties.
    # Marcus Sackrow, PicoQuant GmbH, December 2013
    # Peter Kapusta, PicoQuant GmbH, November 2016
    # Edited script: text output formatting changed by KAP.
    # Julia Tranlation: Rainer Heintzmann
    
    #  Note that marker events have a lower time resolution and may therefore appear
    #  in the file slightly out of order with respect to regular (photon) event records.
    #  This is by design. Markers are designed only for relatively coarse
    #  synchronization requirements such as image scanning.
    
    #  T Mode data are written to an output file [filename].out
    #  We do not keep it in memory because of the huge amout of memory
    #  this would take in case of large files. Of course you can change this,
    #  e.g. if your files are not too big.
    #  Otherwise it is best process the data on the fly and keep only the results.
    
    #  All HeaderData are introduced as Variable to Matlab and can directly be
    #  used for further analysis
    
    # some constants
    tyEmpty8      = 0xFFFF0008
    tyBool8       = 0x00000008
    tyInt8        = 0x10000008
    tyBitSet64    = 0x11000008
    tyColor8      = 0x12000008
    tyFloat8      = 0x20000008
    tyTDateTime   = 0x21000008
    tyFloat8Array = 0x2001FFFF
    tyAnsiString  = 0x4001FFFF
    tyWideString  = 0x4002FFFF
    tyBinaryBlob  = 0xFFFFFFFF
    # RecordTypes
    rtPicoHarpT3     = 0x00010303 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $03 (PicoHarp)
    rtPicoHarpT2     = 0x00010203 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $03 (PicoHarp)
    rtHydraHarpT3    = 0x00010304 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $04 (HydraHarp)
    rtHydraHarpT2    = 0x00010204 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $04 (HydraHarp)
    rtHydraHarp2T3   = 0x01010304 # (SubID = $01 ,RecFmt: $01) (V2), T-Mode: $03 (T3), HW: $04 (HydraHarp)
    rtHydraHarp2T2   = 0x01010204 # (SubID = $01 ,RecFmt: $01) (V2), T-Mode: $02 (T2), HW: $04 (HydraHarp)
    rtTimeHarp260NT3 = 0x00010305 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $05 (TimeHarp260N)
    rtTimeHarp260NT2 = 0x00010205 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $05 (TimeHarp260N)
    rtTimeHarp260PT3 = 0x00010306 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $06 (TimeHarp260P)
    rtTimeHarp260PT2 = 0x00010206 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $06 (TimeHarp260P)
    rtMultiHarpT3    = 0x00010307 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $03 (T3), HW: $07 (MultiHarp)
    rtMultiHarpT2    = 0x00010207 # (SubID = $00 ,RecFmt: $01) (V1), T-Mode: $02 (T2), HW: $07 (MultiHarp)

    # Globals for subroutines
    # fid
    # TTResultFormat_TTTRRecType;
    # TTResult_NumberOfRecords; # Number of TTTR Records in the File;
    # MeasDesc_Resolution;      # Resolution for the Dtime (T3 Only)

    TTResultFormat_TTTRRecType = 0;
    TTResult_NumberOfRecords = 0;
    # MeasDesc_Resolution = 0;
    # MeasDesc_GlobalResolution = 0;
    global MeasDesc_GlobalResolution = 0.0; # needs to be accessed by get_time_conversion()

    # start Main program
    pathname, filename  = splitdir(full_filename) # uigetfile('*.ptu', 'T-Mode data:');
    fid = open(joinpath(pathname,filename))

    print("1\n");
    Magic = read(fid, 8); # , uint8
    if !("PQTTTR" == String(Magic)[1:6])
        error("Magic invalid, this is not an PTU file.");
    end;
    Version = read(fid, 8);
    Version = Version[Version .!= 0]; # remove #0 and more more readable
    println("Tag Version: $(String(Version))");
    TTResult_NumberOfRecords = nothing

    # there is no repeat.. until (or do..while) construct so we use
    # while 1 ... if (expr) break; end; end;
    while true
        # read Tag Head
        TagIdent = read(fid, 32); # TagHead.Ident
        TagIdent = TagIdent[TagIdent .!= 0]; # remove #0 and more more readable
        TagIdx = read(fid, Int32);    # TagHead.Idx
        TagTyp = read(fid, UInt32);   # TagHead.Typ
                                            # TagHead.Value will be read in the
                                            # right type function
        TagIdent = String(TagIdent) # genvarname(TagIdent);    # remove all illegal characters
        TagIdent = replace(TagIdent, !isascii=>' ')
        if TagIdx > -1
            EvalName = TagIdent*"($(TagIdx + 1))";
        else
            EvalName = TagIdent
        end
        @printf("\n   %-40s", EvalName)
        # check Typ of Header
        if TagTyp == tyEmpty8
                read(fid, Int64)
                print("<Empty>")
        elseif  TagTyp == tyBool8
                TagInt = read(fid, Int64);
                if TagInt==0
                    print("FALSE");
                else
                    print("TRUE");
                end
        elseif  TagTyp ==  tyInt8
                TagInt = read(fid, Int64);
                @printf("%d", TagInt);
                if EvalName == "TTResult_NumberOfRecords"
                    TTResult_NumberOfRecords = TagInt
                elseif EvalName == "TTResultFormat_TTTRRecType"
                    TTResultFormat_TTTRRecType = TagInt
                end
        elseif  TagTyp == tyBitSet64
                TagInt = read(fid, Int64);
                @printf("%X", TagInt);
        elseif  TagTyp == tyColor8
                TagInt = read(fid, Int64);
                @printf("%X", TagInt);
        elseif  TagTyp == tyFloat8
                TagFloat = read(fid, Float64);
                @printf("%e", TagFloat);
                if EvalName == "MeasDesc_GlobalResolution"
                    MeasDesc_GlobalResolution = TagFloat
                end
        elseif  TagTyp == tyFloat8Array
                TagInt = read(fid, Int64);
                print("<Float array with $(TagInt / 8) Entries>")
                fseek(fid, TagInt);
        elseif  TagTyp == tyTDateTime
                TagFloat = read(fid, Float64);
                #fprintf(1, '%s', datestr(datenum(1899,12,30)+TagFloat)); # display as Date String
        elseif  TagTyp == tyAnsiString
                TagInt = read(fid, Int64);
                TagString = read(fid, TagInt)
                TagString = String(TagString[TagString .!= 0])
                # TagString = replace(TagString, !isascii=>' ')
                if TagIdx > -1
                    EvalName = "$(TagIdent){$(TagIdx + 1)}"
                end;
                println("$(TagString)")
        elseif TagTyp == tyWideString
                # Just read and remove the 0's (up to current (2012))
                TagInt = read(fid, Int64)
                TagString = read(fid, TagInt)
                TagString = String(TagString[TagString .!= 0])
                # TagString = replace(TagString, !isascii=>' ')
                #TagString = TagString[TagString .!= 0]
                println("$(TagString)")
                if TagIdx > -1
                    EvalName = "$(TagIdent){$(TagIdx + 1)}"
                end;
        elseif  TagTyp == tyBinaryBlob
                TagInt = read(fid, Int64)
                fprintf("<Binary Blob with $(TagInt) Bytes>")
                seek(fid, TagInt)
        else
                error("Illegal Type identifier found! Broken file?")
        end
        if TagIdent == "Header_End"
            break
        end
    end
    print("\n----------------------\n");

    # Check recordtype
    global isT2;
    if TTResultFormat_TTTRRecType == rtPicoHarpT3
            isT2 = false;
            print("PicoHarp T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtPicoHarpT2
            isT2 = true;
            print("PicoHarp T2 data\n");
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT3
            isT2 = false;
            print("HydraHarp V1 T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT2
            isT2 = true;
            print("HydraHarp V1 T2 data\n");
    elseif TTResultFormat_TTTRRecType == rtHydraHarp2T3
            isT2 = false;
            print("HydraHarp V2 T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtHydraHarp2T2
            isT2 = true;
            print("HydraHarp V2 T2 data\n");
    elseif TTResultFormat_TTTRRecType == rtTimeHarp260NT3
            isT2 = false;
            print("TimeHarp260N T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtTimeHarp260NT2
            isT2 = true;
            print("TimeHarp260N T2 data\n");
    elseif TTResultFormat_TTTRRecType == rtTimeHarp260PT3
            isT2 = false;
            print("TimeHarp260P T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtTimeHarp260PT2
            isT2 = true;
            print("TimeHarp260P T2 data\n");
    elseif TTResultFormat_TTTRRecType == rtMultiHarpT3
            isT2 = false;
            print("MultiHarp T3 data\n");
    elseif TTResultFormat_TTTRRecType == rtMultiHarpT2
            isT2 = true;
            print("MultiHarp T2 data\n");
    else
        close(fid)
        error("Illegal RecordType $(TTResultFormat_TTTRRecType)!");
    end;
    print("\nThis may take a while...");
    # choose right decode function
    if TTResultFormat_TTTRRecType == rtPicoHarpT3
            return ReadPT3(fid, TTResult_NumberOfRecords);
            return 
    elseif TTResultFormat_TTTRRecType == rtPicoHarpT2
            isT2 = true;
            return ReadPT2(fid, TTResult_NumberOfRecords);
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT3
            return ReadHT3(1, fid, TTResult_NumberOfRecords);
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT2
            isT2 = true;
            return ReadHT2(1, fid, TTResult_NumberOfRecords);
    elseif TTResultFormat_TTTRRecType in (rtMultiHarpT3, rtHydraHarp2T3, rtTimeHarp260NT3, rtTimeHarp260PT3)
            isT2 = false;
            return ReadHT3(2, fid, TTResult_NumberOfRecords);
    elseif TTResultFormat_TTTRRecType in (rtMultiHarpT2, rtHydraHarp2T2, rtTimeHarp260NT2, rtTimeHarp260PT2)
            isT2 = true;
            return ReadHT2(2, fid, TTResult_NumberOfRecords);
    else
        close(fid)
        error("Illegal RecordType $(TTResultFormat_TTTRRecType)!");
    end;
    # print("Ready!  \n\n")
    # print("\nStatistics obtained from the data:\n")
    # print("\n$(cnt_ph) photons, $(cnt_ov) overflows, $(cnt_ma) markers.")
    # print("\n");
end

function get_time_conversion()
    return MeasDesc_GlobalResolution;
end

# ## Got Photon
# #   TimeTag: Raw TimeTag from Record * Globalresolution = Real Time arrival of Photon
# #    DTime: Arrival time of Photon after last Sync event (T3 only) DTime * Resolution = Real time arrival of Photon after last Sync event
# #    Channel: Channel the Photon arrived (0 = Sync channel for T2 measurements)
# function GotPhoton(TimeTag, Channel, DTime)
#     global isT2;
#     global RecNum;
#     global MeasDesc_GlobalResolution;
#     global cnt_ph;
#     cnt_ph = cnt_ph + 1;
#     if(isT2)
#         # Edited: formatting changed by PK
#         @printf(fpout,"\n%10i CHN %i %18.0f (%0.1f ps)" , RecNum, Channel, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e12));
#     else
#         # Edited: formatting changed by PK
#         @printf(fpout,"\n%10i CHN %i %18.0f (%0.1f ns) %ich", RecNum, Channel, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e9), DTime);
#     end;
# end

# ## Got Marker
# #    TimeTag: Raw TimeTag from Record * Globalresolution = Real Time arrival of Photon
# #    Markers: Bitfield of arrived Markers, different markers can arrive at same time (same record)
# function GotMarker(TimeTag, Markers)
#     global RecNum;
#     global cnt_ma;
#     global MeasDesc_GlobalResolution;
#     cnt_ma = cnt_ma + 1;
#     # Edited: formatting changed by PK
#     @printf(fpout,"\n%10i MAR %i %18.0f (%0.1f ns)", RecNum, Markers, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e9));
# end

# ## Got Overflow
# #  Count: Some TCSPC provide Overflow compression = if no Photons between overflow you get one record for multiple Overflows
# function GotOverflow(Count)
#     global RecNum;
#     global cnt_ov;
#     cnt_ov = cnt_ov + Count;
#     # Edited: formatting changed by PK
#     @printf(fpout,"\n%10i OFL * %i", RecNum, Count);
# end

## Decoder functions

## Read PicoHarp T3
function ReadPT3(fid, TTResult_NumberOfRecords)
    ofltime = 0;
    WRAPAROUND=65536;
    channels = zeros(UInt8, TTResult_NumberOfRecords)
    time_tags = zeros(UInt64, TTResult_NumberOfRecords)
    dtimes = zeros(UInt16, TTResult_NumberOfRecords)

    @showprogress for i=1:TTResult_NumberOfRecords # 
        T3Record = read(fid, UInt32);     # all 32 bits:
    #   +-------------------------------+  +-------------------------------+
    #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
    #   +-------------------------------+  +-------------------------------+
        nsync = T3Record & 65535;       # the lowest 16 bits:
    #   +-------------------------------+  +-------------------------------+
    #   | | | | | | | | | | | | | | | | |  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
    #   +-------------------------------+  +-------------------------------+
        chan = (T3Record >> 28) & 15;   # the upper 4 bits:
    #   +-------------------------------+  +-------------------------------+
    #   |x|x|x|x| | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
    #   +-------------------------------+  +-------------------------------+
        truensync = ofltime + nsync;
        if (chan >= 1) && (chan <=4)
            dtime = (T3Record >> 16) & 4095;
            channels[i] = chan
            time_tags[i] = truensync
            dtimes[i] = dtime
            # GotPhoton(truensync, chan, dtime);  # regular count at Ch1, Rt_Ch1 - Rt_Ch4 when the router is enabled
        else
            if chan == 15 # special record
                markers = (T3Record >> 16) & 15; # where these four bits are markers:
    #   +-------------------------------+  +-------------------------------+
    #   | | | | | | | | | | | | |x|x|x|x|  | | | | | | | | | | | | | | | | |
    #   +-------------------------------+  +-------------------------------+
                if markers == 0                           # then this is an overflow record
                    ofltime = ofltime + WRAPAROUND;       # and we unwrap the numsync (=time tag) overflow
                    channels[i] = 255
                    time_tags[i] = ofltime
                    # GotOverflow(1);
                else
                    channels[i] = 16 + markers
                    time_tags[i] = truensync
                                    # if nonzero, then this is a true marker event
                    # GotMarker(truensync, markers);
                end
            else
                @warn("wrong record tag")
            end
        end
    end
    close(fid)
    return channels, time_tags, dtimes
end

## Read PicoHarp T2
function ReadPT2(fid, TTResult_NumberOfRecords)
    ofltime = 0
    WRAPAROUND=210698240
    channels = zeros(UInt8, TTResult_NumberOfRecords)
    time_tags = zeros(UInt64, TTResult_NumberOfRecords)

    @showprogress for i=1:TTResult_NumberOfRecords # @showprogress 
        T2Record = read(fid, UInt32)
        T2time = T2Record & 268435455;            #the lowest 28 bits
        chan = (T2Record >> 28) & 15      #the next 4 bits
        timetag = T2time + ofltime
        if (chan >= 0) && (chan <= 4)
            channels[i] = chan
            time_tags[i] = timetag
            # GotPhoton(timetag, chan, 0)
        else
            if chan == 15
                markers = T2Record & 15  # where the lowest 4 bits are marker bits
                if markers==0                   # then this is an overflow record
                    ofltime = ofltime + WRAPAROUND # and we unwrap the time tag overflow
                    channels[i] = 255
                    time_tags[i] = ofltime
                    # GotOverflow(1)
                else                            # otherwise it is a true marker
                    channels[i] = 16 + markers
                    time_tags[i] = timetag
                    # GotMarker(timetag, markers)
                end
            else
                @warn("wrong record tag")
            end
        end
        # Strictly, in case of a marker, the lower 4 bits of time are invalid
        # because they carry the marker bits. So one could zero them out.
        # However, the marker resolution is only a few tens of nanoseconds anyway,
        # so we can just ignore the few picoseconds of error.
    end
    close(fid)
    return channels, time_tags
end

## Read HydraHarp/TimeHarp260 T3
function ReadHT3(Version, fid, TTResult_NumberOfRecords)
    OverflowCorrection = 0;
    T3WRAPAROUND = 1024;
    channels = zeros(UInt8, TTResult_NumberOfRecords)
    time_tags = zeros(UInt64, TTResult_NumberOfRecords)
    dtime = zeros(UInt16, TTResult_NumberOfRecords)

    @showprogress for i = 1:TTResult_NumberOfRecords
        RecNum = i;
        T3Record = read(fid, UInt32)     # all 32 bits:
        #   +-------------------------------+  +-------------------------------+
        #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        nsync = T3Record & 1023      # the lowest 10 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | | | | | | | | | | |  | | | | | | |x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        dtime = (T3Record >> 10) & 32767   # the next 15 bits:
        #   the dtime unit depends on "Resolution" that can be obtained from header
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x| | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        channel = (T3Record >> 25) & 63   # the next 6 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        special = (T3Record >> 31) & 1   # the last bit:
        #   +-------------------------------+  +-------------------------------+
        #   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        if special == 0   # this means a regular input channel
            true_nSync = OverflowCorrection + nsync
            #  one nsync time unit equals to "syncperiod" which can be
            #  calculated from "SyncRate"
            channels[i] = channel
            time_tags[i] = true_nSync
            dtimes[i] = dtime
            # GotPhoton(true_nSync, channel, dtime)
        else    # this means we have a special record
            if channel == 63  # overflow of nsync occured
                if (nsync == 0) || (Version == 1) # if nsync is zero it is an old style single oferflow or old Version
                OverflowCorrection = OverflowCorrection + T3WRAPAROUND
                channels[i] = 255
                time_tags[i] = OverflowCorrection
                # GotOverflow(1)
                else         # otherwise nsync indicates the number of overflows - THIS IS NEW IN FORMAT V2.0
                OverflowCorrection = OverflowCorrection + T3WRAPAROUND * nsync
                channels[i] = 255
                time_tags[i] = OverflowCorrection
                # GotOverflow(nsync)
                end;
            end;
            if (channel >= 1) && (channel <= 15)  # these are markers
                true_nSync = OverflowCorrection + nsync
                channels[i] = 16 + channel
                time_tags[i] = true_nSync
                # GotMarker(true_nSync, channel)
            end
        end
    end
    close(fid)
    return channels, time_tags, dtimes
end

## Read HydraHarp/TimeHarp260 T2
function ReadHT2(Version, fid, TTResult_NumberOfRecords)

    OverflowCorrection = 0;
    T2WRAPAROUND_V1=33552000;
    T2WRAPAROUND_V2=33554432; # = 2^25  IMPORTANT! THIS IS NEW IN FORMAT V2.0
    channels = zeros(UInt8, TTResult_NumberOfRecords)
    time_tags = zeros(UInt64, TTResult_NumberOfRecords)

    @showprogress for i=1:TTResult_NumberOfRecords
        RecNum = i;
        T2Record = read(fid, UInt32);     # all 32 bits:
        #   +-------------------------------+  +-------------------------------+
        #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        dtime = T2Record & 33554431;   # the last 25 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        channel = (T2Record >> 25) & 63;   # the next 6 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        special = (T2Record >> 31) & 1;   # the last bit:
        #   +-------------------------------+  +-------------------------------+
        #   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        # the resolution in T2 mode is 1 ps  - IMPORTANT! THIS IS NEW IN FORMAT V2.0
        timetag = OverflowCorrection + dtime;
        if special == 0   # this means a regular photon record
            channels[i] = chan
            time_tags[i] = timetag
            # GotPhoton(timetag, channel + 1, 0)
        else    # this means we have a special record
            if channel == 63  # overflow of dtime occured
                if Version == 1
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V1
                    channels[i] = 255
                    time_tags[i] = OverflowCorrection
                    # GotOverflow(1)
                else
                    if(dtime == 0) # if dtime is zero it is an old style single overflow
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V2
                    channels[i] = 255
                    time_tags[i] = OverflowCorrection
                    # GotOverflow(1)
                    else         # otherwise dtime indicates the number of overflows - THIS IS NEW IN FORMAT V2.0
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V2 * dtime
                    channels[i] = 255
                    time_tags[i] = OverflowCorrection
                    # GotOverflow(dtime)
                    end
                end
            end
            if channel == 0  # Sync event
                channels[i] = channel
                time_tags[i] = timetag
                # GotPhoton(timetag, channel, 0)
            end
            if (channel >= 1) && (channel <= 15)  # these are markers
                channels[i] = 16 + channel
                time_tags[i] = timetag
                # GotMarker(timetag, channel)
            end
        end
    end
    close(fid)
    return channels, time_tags
end

