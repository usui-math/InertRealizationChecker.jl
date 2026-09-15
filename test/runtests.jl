using Test, InertRealizingChecker, TOML
const IRC=InertRealizingChecker
shift(ps)=fixed_shift(MarkerMap(ps))
status(r)=r["status"]

@testset "Input and local rule" begin
    @test MarkerMap(["0∗10","0*10"]).patterns==["0*10"]
    @test_throws ArgumentError MarkerMap(["01"])
    @test_throws ArgumentError MarkerMap(["**"])
    @test_throws ArgumentError MarkerMap(["0*x"])
    @test status(check_involution(MarkerMap()))=="true"
    @test status(check_involution(MarkerMap(["*"])))=="true"
    @test status(check_involution(MarkerMap(["01*10"])))=="false"
    @test status(check_involution(MarkerMap(["0*10"])))=="true"
    @test status(check_involution(MarkerMap(["0*"])))=="false"
    @test status(check_involution(MarkerMap(["01*10"]);limits=Limits(max_window=2)))=="unknown"
    @test_throws IRC.ResourceLimit fixed_shift(MarkerMap(["000000*"]);limits=Limits(max_states=2))
end

@testset "Fine-grid cylinder pairs" begin
    @test cylinder_pairs(String[],4,4)==Tuple{String,String}[]
    pairs=cylinder_pairs(["0□10","110□1110"],4,4)
    @test length(pairs)==17
    @test pairs==sort(unique(pairs))
    @test ("0000.1000","0001.1000") in pairs
    @test ("1100.1110","1101.1110") in pairs
    markers=MarkerMap(pairs)
    @test length(markers.patterns)==17
    @test "000*1000" in markers.patterns
    @test "110*1110" in markers.patterns
    @test !("0*10" in markers.patterns)

    @test cylinder_pairs(["0*10","0∗10","0□10"],4,4)==cylinder_pairs(["0*10"],4,4)
    @test cylinder_pairs(["□"],1,0)==[("0.","1.")]
    @test MarkerMap([("1.0","0.0"),("0.0","1.0"),]).patterns==["*0"]

    @test_throws ArgumentError cylinder_pairs(["*"],0,0)
    @test_throws ArgumentError cylinder_pairs(["*"],1,-1)
    @test_throws ArgumentError cylinder_pairs(["0*10"],1,2)
    @test_throws ArgumentError cylinder_pairs(["0*10"],2,1)
    @test_throws ArgumentError cylinder_pairs(["010"],4,4)
    @test_throws ArgumentError cylinder_pairs(["0□*10"],4,4)
    @test_throws ArgumentError cylinder_pairs(["0x□10"],4,4)

    @test_throws ArgumentError MarkerMap([("000.10","001.1")])
    @test_throws ArgumentError MarkerMap([("00010","00110")])
    @test_throws ArgumentError MarkerMap([("00.0.10","00.1.10")])
    @test_throws ArgumentError MarkerMap([("000.10","00.110")])
    @test_throws ArgumentError MarkerMap([("00x0.10","00x1.10")])
    @test_throws ArgumentError MarkerMap([("000.10","000.10")])
    @test_throws ArgumentError MarkerMap([("000.10","111.10")])
    @test_throws ArgumentError MarkerMap([("000.10","100.10")])
end

function periodic_apply(ps,x)
    n=length(x)
    [any(ps) do p
        u,v=split(p,'*';keepempty=true)
        all(j->x[mod1(i-length(u)+j-1,n)]==u[j],1:length(u)) &&
        all(j->x[mod1(i+j,n)]==v[j],1:length(v))
    end ? (x[i]=='0' ? '1' : '0') : x[i] for i in 1:n]
end
@testset "Finite order within an inclusive bound" begin
    identity=MarkerMap();flip=MarkerMap(["*"])
    @test check_finite_order(identity,1)["order"]==1
    @test check_finite_order(identity,2)["order"]==1
    @test check_finite_order(flip,2)["order"]==2
    @test check_finite_order(flip,1)["reason"]=="no_order_within_bound"
    @test check_finite_order(flip,3)["order"]==2
    @test status(IRC.check_identity_power(flip,3,Limits()))=="false"
    @test status(IRC.check_identity_power(flip,4,Limits()))=="true"
    @test check_finite_order(flip,big(10)^30)["order"]==2
    @test check_finite_order(MarkerMap(["0*10"]),100)["order"]==2
    @test_throws ArgumentError check_finite_order(identity,0)
    @test_throws ArgumentError check_finite_order(identity,-1)
    @test_throws ArgumentError check_finite_order(identity,2;limits=Limits(max_window=0))
    limited=check_finite_order(MarkerMap(["0*10"]),3;limits=Limits(max_window=4))
    @test status(limited)=="unknown"
    @test limited["checked_through"]==1
    @test limited["next_power"]==2
    @test status(check_finite_order(MarkerMap(["0*10"]),2;limits=Limits(max_window=4)))=="unknown"
    @test status(check_finite_order(MarkerMap(["0*10"]),1;limits=Limits(max_window=4)))=="false"
    # Independently repeat each returned counterexample as a periodic sequence.
    for ps in [["0*"],["*0"],["01*10"]]
        r=check_finite_order(MarkerMap(ps),4)
        @test status(r)=="false"
        @test r["checked_through"]==4
        @test length(r["counterexamples"])==4
        for witness in r["counterexamples"]
            x=collect(witness["word"]);y=copy(x)
            for _ in 1:witness["power"];y=periodic_apply(ps,y);end
            @test y[witness["center"]]!=x[witness["center"]]
        end
    end
end
@testset "Involution counterexamples on periodic sequences" begin
    for ps in [["01*10"],["0*10","110*1110"]]
        r=check_involution(MarkerMap(ps));x=collect(r["word"])
        @test periodic_apply(ps,periodic_apply(ps,x))!=x
    end
    for ps in [["0*10"],["0*10","10*111"]], n in 1:8, w in 0:(1<<n)-1
        x=collect(string(w;base=2,pad=n))
        @test periodic_apply(ps,periodic_apply(ps,x))==x
    end
end

@testset "Nonperiodic inclusion and redundant presentations" begin
    # Avoiding 10 permits a transition from all 0 to all 1; both ends are recurrent.
    bridge=IRC.forbidden_shift(["10"])
    constants=IRC.forbidden_shift(["01","10"])
    r=check_inclusion(bridge,constants)
    @test status(r)=="false"
    @test r["word"]=="01"
    @test IRC.traces(bridge,12)==IRC.traces(constants,12)
    witness=r["left_cycle"]^8*r["left_bridge"]*r["word"]*r["right_bridge"]*r["right_cycle"]^8
    @test !occursin("10",witness)
    @test occursin("01",witness)
    a=shift(["0*10"]);b=shift(["0*10","00*10"])
    @test length(a)!=length(b)
    @test status(check_inclusion(a,b))==status(check_inclusion(b,a))=="true"
    @test IRC.traces(a,20)==IRC.traces(b,20)
    @test check_cascade(a,b)["reason"]=="equal_shifts"
end

@testset "Negative decisions and unsupported cases" begin
    full=shift(String[]);empty=shift(["*"])
    r=check_cascade(shift(["*0"]),full)
    @test r["reason"]=="parity_violation"
    @test r["period"]==1
    constants=IRC.forbidden_shift(["01","10"])
    r=check_cascade(empty,constants)
    @test r["reason"]=="quantity_violation"
    @test r["period"]==2
    periodic=IRC.forbidden_shift(["00","11"])
    r=check_cascade(empty,periodic;limits=Limits(max_period=1))
    @test r["reason"]=="outside_hypotheses"
    @test status(r)=="unknown"
    # Long Appendix A.2 matrix: zeta mod 2 holds but quantity fails.
    long=FixedShift(String[],string.(1:4),[[(i,'0'),(mod1(i+1,4),'1')] for i in 1:4])
    @test IRC.nilpotence(long,Limits())==4
    counts=periodic_counts(empty,long,4)
    @test counts.remaining[2]==-4
    @test IRC.violation(counts)["reason"]=="quantity_violation"
end

@testset "Requested edges and independent bound verification" begin
    parent=shift(["0*10"]);middle=shift(["0*10","110*1110"]);child=shift(["0*10","10*111"])
    @test status(check_mixing(parent))=="true"
    @test status(check_mixing(middle))=="true"
    for (y,x) in [(child,middle),(middle,parent),(parent,shift(String[]))]
        r=check_cascade(y,x)
        @test status(r)=="true"
        cert=IRC.growth_certificate(y,x,Limits())
        @test cert.a>cert.b>=1
        @test cert.a>cert.h && cert.h^2>=cert.c
        @test cert.V*(cert.b/cert.a)^cert.M<=cert.L/2
        @test cert.M*cert.U*(cert.h/cert.a)^cert.M<=cert.L/2
        start=max(cert.s,2,cld(numerator(cert.h/(cert.a-cert.h)),denominator(cert.h/(cert.a-cert.h))))
        @test all(start:cert.M-1) do m
            cert.V*(cert.b/cert.a)^m>cert.L/2 || m*cert.U*(cert.h/cert.a)^m>cert.L/2
        end
        counts=periodic_counts(y,x,cert.M+3)
        @test all(>=(0),counts.remaining)
        @test all(n->counts.remaining[n]%(2n)==0,eachindex(counts.remaining))
        # Direct trace inequalities also cover the exact cutoff and nearby periods.
        ta=IRC.traces(x,cert.M+3);tb=IRC.traces(y,cert.M+3)
        @test all(n->ta[n]>=cert.L*cert.a^n,max(cert.s,1):length(ta))
        @test all(n->ta[n]<=cert.U*cert.c^n,eachindex(ta))
        @test all(n->tb[n]<=cert.V*cert.b^n,eachindex(tb))
        # Square only a positive deficit to verify c^(n/2) exactly, including odd n.
        @test all(max(cert.s,2):length(ta)) do n
            deficit=cert.L*cert.a^n-cert.V*cert.b^n-counts.remaining[n]
            deficit<=0 || deficit^2<=(n*cert.U)^2*cert.c^n
        end
    end
end

@testset "Graph and mixing" begin
    full=shift(String[]);empty=shift(["*"])
    @test length(full)==1
    @test length(empty)==0
    @test status(check_mixing(full))=="true"
    @test status(check_mixing(empty))=="false"
    @test status(check_inclusion(empty,full))=="true"
    @test status(check_inclusion(full,empty))=="false"
    # Synthetic presentations exercise periods and nonperiodic bridges directly.
    cycle=FixedShift(String[],["a","b"],[[(2,'0')],[(1,'1')]])
    bridge=FixedShift(String[],["a","b"],[[(1,'0'),(2,'1')],[(2,'1')]])
    @test check_mixing(cycle)["period"]==2
    @test check_mixing(bridge)["reason"]=="not_strongly_connected"
    @test status(check_cascade(full,full))=="false"
    @test status(check_cascade(full,empty))=="false"
end

function brute_fixed(ps,n)
    count(0:(1<<n)-1) do word
        x=collect(string(word;base=2,pad=n))
        all(1:n) do i
            !any(ps) do p
                left,right=split(p,'*';keepempty=true)
                all(j->x[mod1(i-length(left)+j-1,n)]==left[j],1:length(left)) &&
                all(j->x[mod1(i+j,n)]==right[j],1:length(right))
            end
        end
    end
end
@testset "Independent periodic enumeration" begin
    for ps in [String[],["*"],["0*"],["01*10"],["0*10","10*111"],["0*10","110*1110"]]
        x=shift(ps)
        @test IRC.traces(x,10)==[brute_fixed(ps,n) for n in 1:10]
    end
    @test IRC.least_counts(BigInt[2,4,8,16,32,64])==BigInt[2,2,6,12,30,54]
end

@testset "Exact cascade certificates" begin
    full=shift(String[])
    empty=shift(["*"])
    cert=IRC.growth_certificate(empty,full,Limits())
    @test cert.M==9
    @test cert.V==0
    @test cert.M*cert.U*(cert.h/cert.a)^cert.M<=cert.L/2<2cert.M*cert.U*(cert.h/cert.a)^cert.M
    improved=check_cascade(empty,full;limits=Limits(max_period=9))
    @test status(improved)=="true"
    @test improved["checked_periods"]==8
    exhausted=check_cascade(empty,full;limits=Limits(max_period=8))
    @test status(exhausted)=="unknown"
    @test exhausted["reason"]=="resource_limit"
    for ps in [["*"],["0*10"]]
        r=check_cascade(shift(ps),full)
        @test status(r)=="true"
        @test haskey(r,"certificate")
    end
    @test status(check_cascade(shift(["0*10"]),full;limits=Limits(max_period=1)))=="unknown"
    for l in 1:30
        checks,stop=IRC.parity_bound(l)
        @test big(2)^stop>=l*(stop+1)
        @test big(2)^(stop-1)>=l*stop
        for (r,q) in checks
            @test isodd(q)
        end
    end
    for k in 1:8,v in big.([0,1,2,3,16,100])
        lo=IRC.root_floor(v,k);hi=IRC.root_upper(v,k)
        @test lo^k<=v<hi^k
    end
end

@testset "CLI" begin
    @test main(["--help"])==0
    @test main(["invalid"])==2
    mktemp() do path,io
        close(io)
        @test main(["compare",joinpath(@__DIR__,"../examples/full.toml"),path])==0
        @test TOML.parsefile(path)["status"]=="true"
    end
    mktemp() do path,io
        write(io,"[shift]\npatterns = [\"bad\"]\n");close(io)
        @test main(["mixing",path])==2
        write(path,"[shift]\npatterns = [\"0*10\"]\n[limits]\nmax_states=1\n")
        mktemp() do output,handle
            close(handle)
            @test main(["mixing",path,output])==0
            @test TOML.parsefile(output)["reason"]=="resource_limit"
        end
        write(path,"[shift]\npatterns = []\n[limits]\nunknown=1\n")
        @test main(["mixing",path])==2
        write(path,"[shift]\npatterns = []\n[limits]\nmax_states=0\n")
        @test main(["mixing",path])==2
    end
end

include("parallel.jl")
