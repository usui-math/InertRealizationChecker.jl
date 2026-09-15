using Serialization

@testset "Parallel kernels and ordered witnesses" begin
    for target in (1,64,65,257,1025,4096)
        for _ in 1:5
            actual=IRC.first_match(4096;min_chunk=16) do i
                i==target && yield()
                i==target || i==4096
            end
            @test actual==target
        end
    end
    @test isnothing(IRC.first_match(_->false,4096))
    @test isnothing(IRC.first_match(_->true,0))
    # Odd matrix dimensions catch shared bit-word writes across column boundaries.
    n=257
    x=FixedShift(String[],string.(1:n),
        [[(mod1(3i+1,n),'0'),(mod1(7i+2,n),'1')] for i in 1:n])
    a=zeros(Int,n,n)
    for i in 1:n,(j,_) in x.edges[i];a[i,j]+=1;end
    p=[isodd(i*j+i+j) for i in 1:n,j in 1:n]
    product=a*Int.(p)
    for _ in 1:3
        @test IRC.boolean_multiply(x,p,xor)==isodd.(product)
        @test IRC.boolean_multiply(x,p,|)==(product .> 0)
    end
    # Library calls may themselves run inside worker tasks.
    jobs=[Threads.@spawn check_involution(MarkerMap(["0*10","000*1000"])) for _ in 1:4]
    @test all(r->r["status"]=="true",fetch.(jobs))

    # Bulk parsing must throw the first original ArgumentError, not a task wrapper.
    invalid=fill(("0.","1."),4096)
    invalid[1025]=("0.","11.")
    invalid[3073]=("0.","0.")
    error=try MarkerMap(invalid) catch e; e end
    @test error isa ArgumentError
    @test error.msg=="paired cylinders must have equal lengths"
    @test_throws ArgumentError MarkerMap([fill("*",4096);"bad"])
end

@testset "Checked-in example results stay exact" begin
    mktempdir() do dir
        open(joinpath(dir,"stdout.txt"),"w") do io
            for (command,input,expected) in [
                    ("compare","edge1.toml","edge1-result.toml"),
                    ("compare","edge2.toml","edge2-result.toml"),
                    ("compare","full.toml","full-result.toml"),
                    ("mixing","shift.toml","mixing-result.toml"),
                    ("involution","shift.toml","involution-result.toml")]
                output=joinpath(dir,"result.toml")
                code=redirect_stdout(io) do
                    main([command,joinpath(@__DIR__,"../examples",input),output])
                end
                @test code==0
                @test TOML.parsefile(output)==TOML.parsefile(joinpath(@__DIR__,"../examples",expected))
            end
        end
    end
end

@testset "Mixing keeps forward and reverse distances separate" begin
    for n in (3,4,4096,4097,65536,65537)
        cycle=FixedShift(String[],string.(1:n),[[(mod1(i+1,n),'0')] for i in 1:n])
        r=check_mixing(cycle)
        @test r["status"]=="false"
        @test r["period"]==n
    end
end

@testset "Public API equality across thread counts" begin
    mktempdir() do dir
        snapshots=Any[]
        for threads in (1,4)
            path=joinpath(dir,"threads$threads.bin")
            project=dirname(@__DIR__)
            script=joinpath(@__DIR__,"thread_snapshot.jl")
            run(`$(Base.julia_cmd()) --startup-file=no --project=$project --threads=$threads $script $path`)
            push!(snapshots,deserialize(path))
        end
        @test keys(snapshots[1])==keys(snapshots[2])
        for key in keys(snapshots[1])
            @test snapshots[1][key]==snapshots[2][key]
        end
    end
end
