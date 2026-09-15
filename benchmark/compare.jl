using Serialization, TOML, Printf

function compare(prefixes)
    length(prefixes)>=2 || error("usage: compare.jl SERIAL PARALLEL [BASELINE]")
    reference=deserialize(first(prefixes)*".bin")
    for prefix in prefixes[2:end]
        actual=deserialize(prefix*".bin")
        @assert keys(reference)==keys(actual) "different result keys: $prefix"
        matched=true
        for key in keys(reference)
            if reference[key]!=actual[key]
                println("Different result: $prefix / $key\nexpected: $(repr(reference[key];context=:limit=>true))\nactual: $(repr(actual[key];context=:limit=>true))")
                matched=false
            end
        end
        @assert matched "results differ: $prefix"
    end
    println("Exact result equality: ",length(reference)," groups, ",length(prefixes)," runs")
    all(p->isfile(p*".toml"),prefixes) || return
    runs=TOML.parsefile.(prefixes .* ".toml")
    println("| API | Serial (s) | Parallel (s) | Serial / parallel | Baseline / parallel |")
    println("|---|---:|---:|---:|---:|")
    for key in sort!(collect(keys(runs[1]["timings"])))
        serial=runs[1]["timings"][key]["seconds"]
        parallel=runs[2]["timings"][key]["seconds"]
        baseline=length(runs)>=3 ? runs[3]["timings"][key]["seconds"] : serial
        @printf("| %s | %.6f | %.6f | %.2f | %.2f |\n",key,serial,parallel,serial/parallel,baseline/parallel)
    end
end
compare(ARGS)
