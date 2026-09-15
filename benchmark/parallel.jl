# Run with --threads=1 and --threads=4. An optional third argument loads a
# saved src directory, so the same workloads can measure the original code.
using TOML, Serialization
if length(ARGS)>=3
    include(joinpath(ARGS[3],"InertRealizingChecker.jl"))
    using .InertRealizingChecker
else
    using InertRealizingChecker
end

function workloads()
    grid=cylinder_pairs(["0*10"],8,3)
    gridmap=MarkerMap(grid)
    bulkgrid=cylinder_pairs(["*"],10,8)
    bulkpatterns=MarkerMap(bulkgrid).patterns
    parent=fixed_shift(MarkerMap(["0*10"]))
    middle=fixed_shift(MarkerMap(["0*10","110*1110"]))
    child=fixed_shift(MarkerMap(["0*10","10*111"]))
    expanded=fixed_shift(gridmap)
    empty=fixed_shift(MarkerMap(["*"]))
    wide=fixed_shift(MarkerMap(["000000000*1"]))
    involution=MarkerMap(["0*10","0000*10000"])
    n=262144
    large=FixedShift(String[],string.(0:n-1),
        [[(((i<<1|bit)&(n-1))+1,bit==0 ? '0' : '1') for bit in 0:1] for i in 0:n-1])
    [
        "cylinder_pairs" => ()->cylinder_pairs(["*"],10,8),
        "MarkerMap_pairs" => ()->MarkerMap(bulkgrid).patterns,
        "MarkerMap_patterns" => ()->MarkerMap(bulkpatterns).patterns,
        "fixed_shift" => ()->begin
            x=fixed_shift(gridmap);(x.forbidden,x.words,x.edges)
        end,
        "check_involution" => ()->check_involution(involution),
        "check_finite_order" => ()->check_finite_order(involution,2),
        "check_inclusion" => ()->check_inclusion(expanded,expanded),
        "check_mixing" => ()->check_mixing(large),
        "periodic_counts" => ()->periodic_counts(empty,wide,48),
        "check_cascade_edge1" => ()->check_cascade(child,middle),
        "check_cascade_edge2" => ()->check_cascade(middle,parent),
    ]
end

function run_benchmarks()
    output=isempty(ARGS) ? "parallel" : ARGS[1]
    samples=length(ARGS)>=2 ? parse(Int,ARGS[2]) : 5
    samples>0 || error("samples must be positive")
    timings=Dict{String,Any}()
    results=Dict{String,Any}()
    for (name,f) in workloads()
        expected=f() # Compile before timing.
        elapsed=Float64[]
        for _ in 1:samples
            GC.gc()
            t=@elapsed actual=f()
            @assert actual==expected "nondeterministic result: $name"
            push!(elapsed,t)
        end
        timings[name]=Dict("seconds"=>sort(elapsed)[cld(samples,2)],"samples"=>elapsed)
        results[name]=expected
        println(name,": ",timings[name]["seconds"]," s");flush(stdout)
    end
    open(output*".toml","w") do io
        TOML.print(io,Dict("julia"=>string(VERSION),"cpu"=>Sys.CPU_NAME,"os"=>string(Sys.KERNEL),
            "threads"=>Threads.nthreads(),"gc_threads"=>Base.JLOptions().nmarkthreads,"timings"=>timings);sorted=true)
    end
    serialize(output*".bin",results)
end
run_benchmarks()
