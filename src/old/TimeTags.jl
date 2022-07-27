module TimeTags
"""
    Tools for reading an processing PicoQuant `.ptu` time-tagged (list-mode) time correlated single photon counting (TCSPC) data.

    This code is based on the Matlab version of a file that read .ptu data:
    https://github.com/PicoQuant/PicoQuant-Time-Tagged-File-Format-Demos/tree/master/PTU/MatLab/
    Note that it (like the Matlab version) uses eval commands, which makes it dangerous for code injection.

"""

using Printf, ProgressMeter

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
    global fid
    global TTResultFormat_TTTRRecType;
    global TTResult_NumberOfRecords; # Number of TTTR Records in the File;
    global MeasDesc_Resolution;      # Resolution for the Dtime (T3 Only)
    global MeasDesc_GlobalResolution;

    TTResultFormat_TTTRRecType = 0;
    TTResult_NumberOfRecords = 0;
    MeasDesc_Resolution = 0;
    MeasDesc_GlobalResolution = 0;

    # start Main program
    pathname, filename  = splitdir(full_filename) # uigetfile('*.ptu', 'T-Mode data:');
    fid = open(joinpath(pathname,filename))

    print("1\n");
    Magic = read(fid, 8); # , uint8
    if !("PQTTTR" == String(Magic)[1:6])
        error("Magic invalid, this is not an PTU file.");
    end;
    Version = read(fid, 8);
    println("Tag Version: $(String(Version))");

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
        if TagIdx > -1
            EvalName = TagIdent*"($(TagIdx + 1))";
        else
            EvalName = TagIdent
        end
        @printf("\n   %-40s", EvalName)
        # check Typ of Header
        try
        if TagTyp == tyEmpty8
                read(fid, Int64)
                print("<Empty>")
        elseif  TagTyp == tyBool8
                TagInt = read(fid, Int64);
                if TagInt==0
                    print("FALSE");
                    eval(Meta.parse("$(EvalName)=false"))
                else
                    print("TRUE");
                    eval(Meta.parse("$(EvalName)=true"))
                end
        elseif  TagTyp ==  tyInt8
                TagInt = read(fid, Int64);
                print(TagInt);
                eval(Meta.parse("$(EvalName)=$(TagInt)"))
        elseif  TagTyp == tyBitSet64
                TagInt = read(fid, Int64);
                @printf("%X", TagInt);
                eval(Meta.parse("$(EvalName)=$(TagInt)"))
        elseif  TagTyp == tyColor8
                TagInt = read(fid, Int64);
                @printf("%X", TagInt);
                eval(Meta.parse("$(EvalName)=$(TagInt)"))
        elseif  TagTyp == tyFloat8
                TagFloat = read(fid, Float64);
                @printf("%e", TagFloat);
                eval(Meta.parse("$(EvalName)=$(TagFloat)"))
        elseif  TagTyp == tyFloat8Array
                TagInt = read(fid, Int64);
                print("<Float array with $(TagInt / 8) Entries>")
                fseek(fid, TagInt);
        elseif  TagTyp == tyTDateTime
                TagFloat = read(fid, Float64);
                #fprintf(1, '%s', datestr(datenum(1899,12,30)+TagFloat)); # display as Date String
                # eval([EvalName '=datenum(1899,12,30)+TagFloat;']); # but keep in memory as Date Number
        elseif  TagTyp == tyAnsiString
                TagInt = read(fid, Int64);
                TagString = String(read(fid, TagInt))
                # TagString = TagString[TagString .!= 0]
                if TagIdx > -1
                    EvalName = "$(TagIdent){$(TagIdx + 1)}"
                end;
                #println("$(EvalName) = $(TagString)")
                eval(Meta.parse("$(EvalName) = \"$(TagString)\""))
        elseif TagTyp == tyWideString
                # Just read and remove the 0's (up to current (2012))
                TagInt = read(fid, Int64)
                TagString = read(fid, TagInt)
                #TagString = TagString[TagString .!= 0]
                #print(TagString)
                if TagIdx > -1
                    EvalName = "$(TagIdent){$(TagIdx + 1)}"
                end;
                eval(Meta.parse("$(EvalName)=\"$(TagString)\""))
        elseif  TagTyp == tyBinaryBlob
                TagInt = read(fid, Int64)
                fprintf("<Binary Blob with $(TagInt) Bytes>")
                seek(fid, TagInt)
        else
                error("Illegal Type identifier found! Broken file?")
        end
        catch e
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
    print("\nWriting data to $(outfile)");
    print("\nThis may take a while...");
    # write Header
    # if (isT2)
    #     print(fpout, "  record# Type Ch        TimeTag             TrueTime/ps\n");
    # else
    #     print(fpout, "  record# Type Ch        TimeTag             TrueTime/ns            DTime\n");
    # end;
    global cnt_ph;
    global cnt_ov;
    global cnt_ma;
    cnt_ph = 0;
    cnt_ov = 0;
    cnt_ma = 0;
    # choose right decode function
    if TTResultFormat_TTTRRecType == rtPicoHarpT3
            ReadPT3(fid,);
    elseif TTResultFormat_TTTRRecType == rtPicoHarpT2
            isT2 = true;
            ReadPT2!(channels, time_tags);
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT3
            ReadHT3!(1, channels, time_tags);
    elseif TTResultFormat_TTTRRecType == rtHydraHarpT2
            isT2 = true;
            ReadHT2!(1, channels, time_tags);
    elseif TTResultFormat_TTTRRecType in (rtMultiHarpT3, rtHydraHarp2T3, rtTimeHarp260NT3, rtTimeHarp260PT3)
            isT2 = false;
            ReadHT3!(2, channels, time_tags);
    elseif TTResultFormat_TTTRRecType in (rtMultiHarpT2, rtHydraHarp2T2, rtTimeHarp260NT2, rtTimeHarp260PT2)
            isT2 = true;
            ReadHT2!(2, channels, time_tags);
    else
        close(fid)
        error("Illegal RecordType $(TTResultFormat_TTTRRecType)!");
    end;
    close(fid)
    print("Ready!  \n\n")
    print("\nStatistics obtained from the data:\n")
    print("\n$(cnt_ph) photons, $(cnt_ov) overflows, $(cnt_ma) markers.")
    print("\n");
end
    
## Got Photon
#   TimeTag: Raw TimeTag from Record * Globalresolution = Real Time arrival of Photon
#    DTime: Arrival time of Photon after last Sync event (T3 only) DTime * Resolution = Real time arrival of Photon after last Sync event
#    Channel: Channel the Photon arrived (0 = Sync channel for T2 measurements)
function GotPhoton(TimeTag, Channel, DTime)
    global isT2;
    global RecNum;
    global MeasDesc_GlobalResolution;
    global cnt_ph;
    cnt_ph = cnt_ph + 1;
    if(isT2)
        # Edited: formatting changed by PK
        @printf(fpout,"\n%10i CHN %i %18.0f (%0.1f ps)" , RecNum, Channel, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e12));
    else
        # Edited: formatting changed by PK
        @printf(fpout,"\n%10i CHN %i %18.0f (%0.1f ns) %ich", RecNum, Channel, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e9), DTime);
    end;
end

## Got Marker
#    TimeTag: Raw TimeTag from Record * Globalresolution = Real Time arrival of Photon
#    Markers: Bitfield of arrived Markers, different markers can arrive at same time (same record)
function GotMarker(TimeTag, Markers)
    global RecNum;
    global cnt_ma;
    global MeasDesc_GlobalResolution;
    cnt_ma = cnt_ma + 1;
    # Edited: formatting changed by PK
    @printf(fpout,"\n%10i MAR %i %18.0f (%0.1f ns)", RecNum, Markers, TimeTag, (TimeTag * MeasDesc_GlobalResolution * 1e9));
end

## Got Overflow
#  Count: Some TCSPC provide Overflow compression = if no Photons between overflow you get one record for multiple Overflows
function GotOverflow(Count)
    global RecNum;
    global cnt_ov;
    cnt_ov = cnt_ov + Count;
    # Edited: formatting changed by PK
    @printf(fpout,"\n%10i OFL * %i", RecNum, Count);
end

## Decoder functions

## Read PicoHarp T3
function ReadPT3(fid, TTResult_NumberOfRecords)
    global RecNum;
    ofltime = 0;
    WRAPAROUND=65536;
    channels = zeros(UInt8, TTResult_NumberOfRecords)
    time_tags = zeros(UInt16, TTResult_NumberOfRecords)

    @showprogress for i=1:TTResult_NumberOfRecords
        RecNum = i;
        T3Record = read(fid, UInt32);     # all 32 bits:
    #   +-------------------------------+  +-------------------------------+
    #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
    #   +-------------------------------+  +-------------------------------+
        nsync = T3Record & 65535;       # the lowest 16 bits:
    #   +-------------------------------+  +-------------------------------+
    #   | | | | | | | | | | | | | | | | |  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
    #   +-------------------------------+  +-------------------------------+
        chan = (T3Record << 28) & 15;   # the upper 4 bits:
    #   +-------------------------------+  +-------------------------------+
    #   |x|x|x|x| | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
    #   +-------------------------------+  +-------------------------------+
        truensync = ofltime + nsync;
        if (chan >= 1) && (chan <=4)
            dtime = (T3Record << 16) & 4095;
            GotPhoton(truensync, chan, dtime);  # regular count at Ch1, Rt_Ch1 - Rt_Ch4 when the router is enabled
        else
            if chan == 15 # special record
                markers = (T3Record << 16) & 15; # where these four bits are markers:
    #   +-------------------------------+  +-------------------------------+
    #   | | | | | | | | | | | | |x|x|x|x|  | | | | | | | | | | | | | | | | |
    #   +-------------------------------+  +-------------------------------+
                if markers == 0                           # then this is an overflow record
                    ofltime = ofltime + WRAPAROUND;       # and we unwrap the numsync (=time tag) overflow
                    GotOverflow(1);
                else                                    # if nonzero, then this is a true marker event
                    GotMarker(truensync, markers);
                end;
            else
                print(fpout,"Err ");
            end;
        end;
    end;
end

## Read PicoHarp T2
function ReadPT2!(channels, time_tags)
    global fid
    global fpout
    global RecNum
    global TTResult_NumberOfRecords # Number of TTTR Records in the File;
    ofltime = 0
    WRAPAROUND=210698240

    @showprogress for i=1:TTResult_NumberOfRecords
        RecNum = i
        T2Record = read(fid, UInt32)
        T2time = T2Record & 268435455;            #the lowest 28 bits
        chan = (T2Record << 28) & 15      #the next 4 bits
        timetag = T2time + ofltime
        if (chan >= 0) && (chan <= 4)
            GotPhoton(timetag, chan, 0)
        else
            if chan == 15
                markers = T2Record & 15  # where the lowest 4 bits are marker bits
                if markers==0                   # then this is an overflow record
                    ofltime = ofltime + WRAPAROUND # and we unwrap the time tag overflow
                    GotOverflow(1)
                else                            # otherwise it is a true marker
                    GotMarker(timetag, markers)
                end
            els
                print(fpout,"Err")
            end
        end
        # Strictly, in case of a marker, the lower 4 bits of time are invalid
        # because they carry the marker bits. So one could zero them out.
        # However, the marker resolution is only a few tens of nanoseconds anyway,
        # so we can just ignore the few picoseconds of error.
    end
end

## Read HydraHarp/TimeHarp260 T3
function ReadHT3!(Version, channels, time_tags)
    global fid;
    global RecNum;
    global TTResult_NumberOfRecords; # Number of TTTR Records in the File
    OverflowCorrection = 0;
    T3WRAPAROUND = 1024;

    for i = 1:TTResult_NumberOfRecords
        RecNum = i;
        T3Record = read(fid, UInt32)     # all 32 bits:
        #   +-------------------------------+  +-------------------------------+
        #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        nsync = T3Record & 1023      # the lowest 10 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | | | | | | | | | | |  | | | | | | |x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        dtime = (T3Record << 10) & 32767   # the next 15 bits:
        #   the dtime unit depends on "Resolution" that can be obtained from header
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x| | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        channel = (T3Record << 25) & 63   # the next 6 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        special = (T3Record << 31) & 1   # the last bit:
        #   +-------------------------------+  +-------------------------------+
        #   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        if special == 0   # this means a regular input channel
            true_nSync = OverflowCorrection + nsync
            #  one nsync time unit equals to "syncperiod" which can be
            #  calculated from "SyncRate"
            GotPhoton(true_nSync, channel, dtime)
        else    # this means we have a special record
            if channel == 63  # overflow of nsync occured
                if (nsync == 0) || (Version == 1) # if nsync is zero it is an old style single oferflow or old Version
                OverflowCorrection = OverflowCorrection + T3WRAPAROUND
                GotOverflow(1)
                else         # otherwise nsync indicates the number of overflows - THIS IS NEW IN FORMAT V2.0
                OverflowCorrection = OverflowCorrection + T3WRAPAROUND * nsync
                GotOverflow(nsync)
                end;
            end;
            if (channel >= 1) && (channel <= 15)  # these are markers
                true_nSync = OverflowCorrection + nsync
                GotMarker(true_nSync, channel)
            end
        end
    end
end

## Read HydraHarp/TimeHarp260 T2
function ReadHT2!(Version, channels, time_tags)
    global fid;
    global TTResult_NumberOfRecords; # Number of TTTR Records in the File;
    global RecNum;

    OverflowCorrection = 0;
    T2WRAPAROUND_V1=33552000;
    T2WRAPAROUND_V2=33554432; # = 2^25  IMPORTANT! THIS IS NEW IN FORMAT V2.0

    for i=1:TTResult_NumberOfRecords
        RecNum = i;
        T2Record = read(fid, UInt32);     # all 32 bits:
        #   +-------------------------------+  +-------------------------------+
        #   |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        dtime = T2Record & 33554431;   # the last 25 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | | | | | | | |x|x|x|x|x|x|x|x|x|  |x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|x|
        #   +-------------------------------+  +-------------------------------+
        channel = (T2Record << 25) & 63;   # the next 6 bits:
        #   +-------------------------------+  +-------------------------------+
        #   | |x|x|x|x|x|x| | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        special = (T2Record << 31) & 1;   # the last bit:
        #   +-------------------------------+  +-------------------------------+
        #   |x| | | | | | | | | | | | | | | |  | | | | | | | | | | | | | | | | |
        #   +-------------------------------+  +-------------------------------+
        # the resolution in T2 mode is 1 ps  - IMPORTANT! THIS IS NEW IN FORMAT V2.0
        timetag = OverflowCorrection + dtime;
        if special == 0   # this means a regular photon record
            GotPhoton(timetag, channel + 1, 0)
        else    # this means we have a special record
            if channel == 63  # overflow of dtime occured
                if Version == 1
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V1
                    GotOverflow(1)
                else
                    if(dtime == 0) # if dtime is zero it is an old style single oferflow
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V2
                    GotOverflow(1)
                    else         # otherwise dtime indicates the number of overflows - THIS IS NEW IN FORMAT V2.0
                    OverflowCorrection = OverflowCorrection + T2WRAPAROUND_V2 * dtime
                    GotOverflow(dtime)
                    end
                end
            end
            if channel == 0  # Sync event
                GotPhoton(timetag, channel, 0)
            end
            if (channel >= 1) && (channel <= 15)  # these are markers
                GotMarker(timetag, channel)
            end
        end
    end
end

end # module
