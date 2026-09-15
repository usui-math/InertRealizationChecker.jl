function main(args=ARGS)
    if isempty(args) || first(args) in ("-h","--help")
        println("Usage: julia --project=. bin/check.jl compare|mixing|involution INPUT.toml [OUTPUT.toml]")
        return 0
    end
    if !(length(args) in (2,3)) || !(args[1] in ("compare","mixing","involution"))
        println(stderr,"Invalid command. Use --help.");return 2
    end
    try
        data=TOML.parsefile(args[2])
        settings=get(data,"limits",Dict())
        allowed=string.(fieldnames(Limits))
        all(k->k in allowed,keys(settings)) || throw(ArgumentError("unknown limit"))
        limits=validate(Limits(; (Symbol(k)=>v for (k,v) in settings)...))
        marker(name)=MarkerMap(String.(data[name]["patterns"]))
        out=guarded() do
            if args[1]=="compare"
                child=marker("child");parent=marker("parent")
                report=check_cascade(fixed_shift(child;limits),fixed_shift(parent;limits);limits)
                report["input"]=Dict("child_patterns"=>child.patterns,"parent_patterns"=>parent.patterns)
                report
            elseif args[1]=="mixing"
                check_mixing(fixed_shift(marker("shift");limits))
            else
                check_involution(marker("shift");limits)
            end
        end
        TOML.print(stdout,out;sorted=true)
        if length(args)==3
            open(args[3],"w") do io;TOML.print(io,out;sorted=true);end
        end
        return 0
    catch e
        e isa InterruptException && rethrow()
        println(stderr,"Error: ",sprint(showerror,e));return 2
    end
end
