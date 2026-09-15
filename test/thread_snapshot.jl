# Standalone snapshot for cross-process equality; optionally load old sources.
using Serialization, TOML
if length(ARGS)>=2
    include(joinpath(ARGS[2],"InertRealizingChecker.jl"))
    using .InertRealizingChecker
else
    using InertRealizingChecker
end
const IRC=InertRealizingChecker
graph(x)=(x.forbidden,x.words,x.edges)
function caught(f)
    try
        f()
    catch e
        (string(nameof(typeof(e))),sprint(showerror,e))
    end
end

function snapshot()
    out=Dict{String,Any}()
    inputs=[String[],["*"],["0*"],["*0"],["01*10"],["0*10"],
            ["0*10","10*111"],["0*10","110*1110"],["0*10","000*1000"],
            ["0000*1111"]]
    maps=MarkerMap.(inputs)
    shifts=fixed_shift.(maps)
    out["limits"]=Tuple(getfield(Limits(),f) for f in fieldnames(Limits))
    out["patterns"]=[m.patterns for m in maps]
    out["graphs"]=graph.(shifts)
    out["involution"]=check_involution.(maps)
    out["order"]=[check_finite_order(m,4;limits=Limits(max_window=17)) for m in maps]
    out["mixing"]=check_mixing.(shifts)
    out["inclusion"]=[check_inclusion(y,x) for y in shifts,x in shifts]
    out["counts"]=[periodic_counts(y,x,16) for y in shifts,x in shifts]
    out["empty_counts"]=periodic_counts(shifts[2],shifts[1],0)
    out["cascades"]=[check_cascade(shifts[y],shifts[x]) for (y,x) in
                     [(7,8),(8,6),(6,1),(1,1),(1,2),(3,1)]]
    pairs=cylinder_pairs(["0□10","00*10","0∗10"],9,7)
    out["pairs"]=pairs
    out["pair_map"]=MarkerMap(pairs).patterns
    expanded=fixed_shift(MarkerMap(cylinder_pairs(["0*10"],8,3)))
    out["expanded_graph"]=graph(expanded)
    out["expanded_inclusion"]=check_inclusion(expanded,expanded)
    # Place the first forbidden word that occurs after the serial search prefix.
    words=[string(i;base=2,pad=8) for i in 0:254]
    push!(words,"11111111")
    constants=FixedShift(words,["1"],[[(1,'1')]])
    out["late_inclusion_witness"]=check_inclusion(constants,constants)
    bridge=IRC.forbidden_shift(["10"])
    out["bridge"]=check_inclusion(bridge,IRC.forbidden_shift(["01","10"]))
    n=65536
    full=FixedShift(String[],string.(0:n-1),
        [[(((i<<1|b)&(n-1))+1,b==0 ? '0' : '1') for b in 0:1] for i in 0:n-1])
    disconnected=FixedShift(String[],string.(1:n),[[(i,'0')] for i in 1:n])
    # Cycles intentionally differ from the old buggy implementation; their exact
    # periods, including odd cycles, are asserted independently in parallel.jl.
    out["large_mixing"]=check_mixing.([full,disconnected])
    mod2=FixedShift(String[],string.(0:255),
        [[(((i<<1|b)&255)+1,b==0 ? '0' : '1') for b in 0:1] for i in 0:255])
    out["nilpotence"]=IRC.nilpotence(mod2,Limits())
    out["boolean_counts"]=periodic_counts(shifts[2],mod2,32)
    out["errors"]=[
        caught(()->MarkerMap(["bad"])),
        caught(()->MarkerMap([("00.0","11.0")])),
        caught(()->cylinder_pairs(["0*"],1,0)),
        caught(()->fixed_shift(maps[6];limits=Limits(max_states=1))),
        caught(()->periodic_counts(shifts[2],shifts[1],2;limits=Limits(max_period=1))),
        caught(()->check_finite_order(maps[1],0)),
        check_finite_order(maps[6],3;limits=Limits(max_window=4)),
        check_involution(maps[6];limits=Limits(max_window=4)),
        check_cascade(shifts[6],shifts[1];limits=Limits(max_period=1)),
        check_cascade(shifts[8],shifts[6];limits=Limits(max_power=1)),
    ]
    # Exercise the CLI through the exported entry point and preserve saved data.
    out["cli"]=mktempdir() do dir
        records=Any[]
        open(joinpath(dir,"stdout.txt"),"w") do io
            redirect_stdout(io) do
                for (command,file) in [("compare","edge1.toml"),("compare","edge2.toml"),
                                       ("mixing","shift.toml"),("involution","shift.toml")]
                    output=joinpath(dir,"result.toml")
                    code=main([command,joinpath(@__DIR__,"../examples",file),output])
                    push!(records,(code,TOML.parsefile(output)))
                end
            end
        end
        records
    end
    out
end
serialize(ARGS[1],snapshot())
