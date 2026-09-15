module InertRealizingChecker

using TOML
export MarkerMap, FixedShift, Limits, cylinder_pairs, fixed_shift, check_involution, check_finite_order,
       check_inclusion, check_mixing, check_cascade, periodic_counts, main

Base.@kwdef struct Limits
    max_states::Int = 1024
    max_period::Int = 10000
    max_power::Int = 256
    max_window::Int = 24
end
struct ResourceLimit <: Exception
    message::String
end
Base.showerror(io::IO, e::ResourceLimit) = print(io, e.message)
result(status, reason; kw...) = Dict{String,Any}("status"=>status, "reason"=>reason,
                                               (string(k)=>v for (k,v) in kw)...)
function guarded(f)
    try
        f()
    catch e
        e isa ResourceLimit || rethrow()
        result("unknown", "resource_limit"; detail=e.message)
    end
end
function validate(l::Limits)
    all(x->x>0, (l.max_states,l.max_period,l.max_power,l.max_window)) ||
        throw(ArgumentError("all limits must be positive"))
    l
end

# Each task owns a contiguous range; never use thread IDs as buffer indices.
# Keep small inputs serial, including when called from another worker task.
function foreach_chunk(f,n::Integer;min_chunk::Int=1)
    nt=Int(min(Threads.nthreads(),max(1,n÷min_chunk)))
    if nt==1
        f(1:n,1)
    else
        size,extra=divrem(n,nt)
        Threads.@threads :dynamic for chunk in 1:nt
            first=(chunk-1)*size+min(chunk-1,extra)+1
            last=chunk*size+min(chunk,extra)
            f(first:last,chunk)
        end
    end
    nt
end

# Preserve the first witness in input order, even if a later task finishes first.
function first_match(f,n::Int;min_chunk::Int=256,serial_prefix::Int=64)
    prefix=min(n,serial_prefix)
    for i in 1:prefix
        f(i) && return i
    end
    best=Threads.Atomic{Int}(n+1)
    foreach_chunk(n-prefix;min_chunk) do indices,_
        for offset in indices
            i=prefix+offset
            i>=best[] && break
            if f(i)
                Threads.atomic_min!(best,i)
                break
            end
        end
    end
    best[]==n+1 ? nothing : best[]
end

struct MarkerMap
    patterns::Vector{String}
    function MarkerMap(patterns::AbstractVector{<:AbstractString})
        strings=collect(String,patterns)
        foreach_chunk(length(strings);min_chunk=2048) do indices,_
            for i in indices;strings[i]=replace(strings[i],'∗'=>'*');end
        end
        ps=sort!(unique(strings))
        invalid=first_match(length(ps);min_chunk=256,serial_prefix=1) do i
            p=ps[i]
            count(==('*'),p)!=1 || !all(c->c in "01*",p)
        end
        isnothing(invalid) ||
            throw(ArgumentError("patterns must contain exactly one * and otherwise only 0 or 1"))
        new(ps)
    end
end
MarkerMap() = MarkerMap(String[])

function MarkerMap(pairs::AbstractVector{<:Tuple{<:AbstractString,<:AbstractString}})
    length(pairs)<2048 && return MarkerMap([pair_pattern(pair...) for pair in pairs])
    inputs=collect(pairs)
    parsed=Vector{Union{String,ArgumentError}}(undef,length(inputs))
    foreach_chunk(length(inputs);min_chunk=1024) do indices,_
        for i in indices
            parsed[i]=try
                pair_pattern(inputs[i]...)
            catch e
                e isa ArgumentError || rethrow()
                e
            end
        end
    end
    patterns=String[]
    for p in parsed
        p isa ArgumentError && throw(p) # Preserve the first input error and its type.
        push!(patterns,p)
    end
    MarkerMap(patterns)
end

function pair_pattern(first::AbstractString,second::AbstractString)
    a=collect(String(first));b=collect(String(second))
    length(a)==length(b) || throw(ArgumentError("paired cylinders must have equal lengths"))
    all(c->c in "01.",a) && all(c->c in "01.",b) ||
        throw(ArgumentError("paired cylinders must contain only 0, 1, and one ."))
    dots_a=findall(==('.'),a);dots_b=findall(==('.'),b)
    length(dots_a)==length(dots_b)==1 && only(dots_a)==only(dots_b) ||
        throw(ArgumentError("paired cylinders must have one . in the same position"))
    differences=findall(i->a[i]!=b[i],eachindex(a))
    length(differences)==1 ||
        throw(ArgumentError("paired cylinders must differ in exactly one bit"))
    center=only(differences);dot=only(dots_a)
    center==dot-1 || throw(ArgumentError("paired cylinders must differ immediately before ."))
    ((a[center]=='0' && b[center]=='1') || (a[center]=='1' && b[center]=='0')) ||
        throw(ArgumentError("paired cylinders must exchange 0 and 1"))
    a[center]='*';deleteat!(a,dot)
    String(a)
end

"""
    cylinder_pairs(local_rules, head_length, tail_length)

Expand binary local rules to exact `head.tail` cylinder pairs. The head includes
the current symbol. `*`, `∗`, and `□` all mark that symbol in a local rule.
"""
function cylinder_pairs(local_rules::AbstractVector{<:AbstractString},
                        head_length::Integer,tail_length::Integer)::Vector{Tuple{String,String}}
    head_length>=1 || throw(ArgumentError("head_length must be at least 1"))
    tail_length>=0 || throw(ArgumentError("tail_length must be nonnegative"))
    head_length<=typemax(Int) && tail_length<=typemax(Int) ||
        throw(ArgumentError("head_length and tail_length must fit in Int"))
    h=Int(head_length);t=Int(tail_length)
    rules=sort!(unique(replace(String(rule),'∗'=>'*','□'=>'*') for rule in local_rules))
    pairs=Set{Tuple{String,String}}()
    for rule in rules
        count(==('*'),rule)==1 && all(c->c in "01*",rule) ||
            throw(ArgumentError("local rules must contain exactly one center and otherwise only 0 or 1"))
        left,right=split(rule,'*';keepempty=true)
        free_left=h-length(left)-1;free_right=t-length(right)
        free_left>=0 && free_right>=0 ||
            throw(ArgumentError("local rule does not fit the requested head and tail lengths"))
        right_count=big(2)^free_right
        total_count=big(2)^free_left*right_count
        # Avoid BigInt division for every generated pair when indices fit in Int.
        total=total_count<=typemax(Int) ? Int(total_count) : total_count
        nr=total isa Int ? Int(right_count) : right_count
        partial=[Tuple{String,String}[] for _ in 1:min(Threads.nthreads(),max(1,total÷2048))]
        foreach_chunk(total;min_chunk=2048) do indices,chunk
            local_pairs=partial[chunk]
            for index in indices
                i,j=divrem(index-1,nr)
                prefix=string(i;base=2,pad=free_left);suffix=string(j;base=2,pad=free_right)
                push!(local_pairs,(prefix*left*"0."*right*suffix,
                                   prefix*left*"1."*right*suffix))
            end
        end
        # One rule generates distinct pairs in lexicographic order. Concatenating
        # ordered chunks needs neither a shared Set nor a final sort in this case.
        length(rules)==1 && return reduce(vcat,partial)
        foreach(p->union!(pairs,p),partial)
    end
    sort!(collect(pairs))
end

struct FixedShift
    forbidden::Vector{String}
    words::Vector{String}
    edges::Vector{Vector{Tuple{Int,Char}}}
end
Base.length(x::FixedShift) = length(x.edges)

function fixed_shift(m::MarkerMap; limits=Limits())
    forb = sort!(unique([replace(p,'*'=>c) for p in m.patterns for c in "01"]))
    forbidden_shift(forb;limits)
end
function forbidden_shift(forb::Vector{String}; limits=Limits())
    validate(limits)
    width = isempty(forb) ? 0 : maximum(length,forb)-1
    width < 8sizeof(Int)-2 && big(2)^width <= limits.max_states ||
        throw(ResourceLimit("higher-block graph exceeds max_states=$(limits.max_states)"))
    n = 1 << width
    words = [width==0 ? "" : string(i;base=2,pad=width) for i in 0:n-1]
    edges = [Tuple{Int,Char}[] for _ in 1:n]
    foreach_chunk(n;min_chunk=128) do indices,_
        for i in indices, c in "01"
            w = words[i]*c
            any(f->occursin(f,w),forb) && continue
            j = width==0 ? 1 : (((i-1)<<1 | (c=='1')) & (n-1))+1
            push!(edges[i],(j,c))
        end
    end
    # Keep bridges between cyclic components: they represent nonperiodic points.
    alive = trues(n)
    while true
        incoming = falses(n); outgoing = falses(n)
        for i in 1:n
            alive[i] || continue
            for (j,_) in edges[i]
                alive[j] || continue
                outgoing[i]=true; incoming[j]=true
            end
        end
        next = alive .& incoming .& outgoing
        next == alive && break
        alive = next
    end
    ids=findall(alive); index=zeros(Int,n); index[ids]=1:length(ids)
    FixedShift(forb,words[ids], [[(index[j],c) for (j,c) in edges[i] if alive[j]] for i in ids])
end

function check_identity_power(m::MarkerMap, k::Int, limits::Limits)
    parts=[split(p,'*';keepempty=true) for p in m.patterns]
    left=maximum((length(p[1]) for p in parts);init=0)
    right=maximum((length(p[2]) for p in parts);init=0)
    width=big(k)*(left+right)+1
    width<=limits.max_window && width<8sizeof(Int)-2 ||
        throw(ResourceLimit("$k applications require window $width > supported window limit"))
    width=Int(width);center=k*left+1
    flip(x,i)=any(p->all(j->x[i-length(p[1])+j-1]==p[1][j],1:length(p[1])) &&
                      all(j->x[i+j]==p[2][j],1:length(p[2])),parts)
    mismatch=first_match(1<<width) do index
        word=index-1
        original=string(word;base=2,pad=width)
        x=collect(original)
        # Each simultaneous update removes the boundary whose inputs are unknown.
        # After k updates only the central output remains.
        for _ in 1:k
            x=[flip(x,i) ? (x[i]=='0' ? '1' : '0') : x[i]
               for i in left+1:length(x)-right]
        end
        x[1]!=original[center]
    end
    if !isnothing(mismatch)
        witness=string(mismatch-1;base=2,pad=width)
        return result("false","power_not_identity";word=witness,center=center,power=k,window=width)
    end
    result("true","power_is_identity";power=k,window=width)
end

function check_involution(m::MarkerMap; limits=Limits())
    guarded() do
        validate(limits)
        r=check_identity_power(m,2,limits)
        r["reason"]=r["status"]=="true" ? "local_rule_squared_is_identity" : "not_involution"
        delete!(r,"power")
        r
    end
end

"""
    check_finite_order(m::MarkerMap, n::Integer; limits=Limits())

Test whether some positive iteration count at most `n` gives the identity.
Return the smallest such count as `order`, or `false` after excluding all candidates.
A resource limit returns `unknown`; `false` does not assert infinite order.
"""
function check_finite_order(m::MarkerMap, n::Integer; limits=Limits())
    n>=1 || throw(ArgumentError("n must be a positive integer"))
    validate(limits)
    witnesses=Dict{String,Any}[]
    k=1
    while k<=n
        r=guarded() do
            check_identity_power(m,k,limits)
        end
        if r["status"]=="true"
            return result("true","finite_order_found";order=k,window=r["window"],checked_through=k)
        elseif r["status"]=="unknown"
            r["checked_through"]=k-1;r["next_power"]=k;r["counterexamples"]=witnesses
            return r
        end
        push!(witnesses,r)
        k+=1
    end
    result("false","no_order_within_bound";checked_through=k-1,counterexamples=witnesses)
end

function extension(x::FixedShift, start::Int, backwards::Bool)
    edges = backwards ? [Tuple{Int,Char}[] for _ in 1:length(x)] : x.edges
    if backwards
        for i in eachindex(x.edges), (j,c) in x.edges[i]; push!(edges[j],(i,c)); end
    end
    seen=Dict{Int,Int}(); labels=Char[]; v=start
    while !haskey(seen,v)
        seen[v]=length(labels)+1
        v,c=first(edges[v]); push!(labels,c)
    end
    cut=seen[v]
    bridge=labels[1:cut-1]; cycle=labels[cut:end]
    backwards && (reverse!(bridge);reverse!(cycle))
    String(bridge),String(cycle)
end
function word_path(x::FixedShift, word::String)
    # One predecessor per state suffices for the existential language query.
    current=Dict(i=>Int[i] for i in 1:length(x))
    for c in word
        next=Dict{Int,Vector{Int}}()
        for (i,path) in current, (j,label) in x.edges[i]
            label==c && !haskey(next,j) && (next[j]=[path;j])
        end
        current=next
        isempty(current) && return nothing
    end
    isempty(current) ? nothing : current[minimum(keys(current))]
end
function check_inclusion(child::FixedShift,parent::FixedShift)
    index=first_match(length(parent.forbidden);min_chunk=8,serial_prefix=1) do i
        !isnothing(word_path(child,parent.forbidden[i]))
    end
    if !isnothing(index)
        word=parent.forbidden[index];path=word_path(child,word)
        lb,lc=extension(child,first(path),true); rb,rc=extension(child,last(path),false)
        return result("false","forbidden_word_in_child";word=word,
                      left_cycle=lc,left_bridge=lb,right_bridge=rb,right_cycle=rc)
    end
    result("true","language_inclusion")
end
function check_mixing(x::FixedShift)
    n=length(x)
    n==0 && return result("false","empty_shift")
    function distances(neighbors,vertex)
        local d=fill(-1,n)
        d[1]=0;queue=[1]
        for i in queue, edge in neighbors(i)
            j=vertex(edge)
            d[j]>=0 && continue
            d[j]=d[i]+1;push!(queue,j)
        end
        d
    end
    function reverse_distances()
        # Store incoming edges contiguously instead of allocating a vector for
        # every vertex; reverse graph construction otherwise dominates this scan.
        starts=zeros(Int,n+1);starts[1]=1
        for edges in x.edges,(j,_) in edges;starts[j+1]+=1;end
        cumsum!(starts,starts)
        incoming=Vector{Int}(undef,starts[end]-1);positions=copy(starts)
        for i in 1:n,(j,_) in x.edges[i]
            incoming[positions[j]]=i;positions[j]+=1
        end
        distances(i->view(incoming,starts[i]:starts[i+1]-1),identity)
    end
    if n>=65536 && Threads.nthreads()>1
        backward=Threads.@spawn reverse_distances()
        d=distances(i->x.edges[i],first);unreachable=any(==(-1),fetch(backward))
    else
        d=distances(i->x.edges[i],first);unreachable=any(==(-1),d) || any(==(-1),reverse_distances())
    end
    (any(==(-1),d) || unreachable) &&
        return result("false","not_strongly_connected";states=n)
    period=0
    for i in 1:n,(j,_) in x.edges[i];period=gcd(period,abs(d[i]+1-d[j]));end
    result(period==1 ? "true" : "false",period==1 ? "primitive" : "periodic";period=period,states=n)
end

function multiply(x::FixedShift,p::Matrix{BigInt})
    n=length(x);out=Matrix{BigInt}(undef,n,size(p,2));z=big(0)
    for k in axes(p,2), i in 1:n
        edges=x.edges[i]
        # BigInts are shared read-only; additions create new values. Avoid a
        # zero addition (and its allocation) for the first edge in every cell.
        value=isempty(edges) ? z : p[edges[1][1],k]
        for edge in 2:length(edges);value+=p[edges[edge][1],k];end
        out[i,k]=value
    end
    out
end
function traces(x::FixedShift,N::Int)
    N==0 && return BigInt[]
    n=length(x)
    partial=Vector{Vector{BigInt}}(undef,Threads.nthreads())
    # A column depends only on the same column of the previous power. Keep it
    # in one task for all periods, avoiding a barrier at every matrix product.
    nt=foreach_chunk(n;min_chunk=max(1,cld(32768,max(1,n*N)))) do columns,chunk
        p=zeros(BigInt,n,length(columns))
        for (j,i) in enumerate(columns);p[i,j]=1;end
        values=Vector{BigInt}(undef,N)
        for power in 1:N
            p=multiply(x,p)
            values[power]=sum((p[i,j] for (j,i) in enumerate(columns));init=big(0))
        end
        partial[chunk]=values
    end
    out=zeros(BigInt,N)
    for chunk in 1:nt;out .+= partial[chunk];end
    out
end
function least_counts(f::Vector{BigInt})
    p=copy(f)
    for n in eachindex(p), multiple in 2n:n:length(p);p[multiple]-=p[n];end
    p
end
function periodic_counts(child::FixedShift,parent::FixedShift,N::Integer;limits=Limits())
    validate(limits)
    0<=N<=limits.max_period || throw(ResourceLimit("period outside 0:max_period"))
    f=traces(parent,Int(N))-traces(child,Int(N));p=least_counts(f)
    d=zeros(BigInt,N);c=copy(p)
    for n in 2:2:N;d[n]=d[n÷2]+p[n÷2];c[n]-=d[n];end
    (fixed=f,least=p,required=d,remaining=c)
end

function violation(counts)
    for n in eachindex(counts.remaining)
        c=counts.remaining[n];modulus=big(2)^(trailing_zeros(n)+1)
        c<0 && return result("false","quantity_violation";period=n,remaining=string(c))
        c%modulus!=0 && return result("false","parity_violation";
                                     period=n,remaining=string(c),modulus=string(modulus))
    end
    nothing
end
function outside_result(child,parent,limits;kw...)
    N=min(64,limits.max_period)
    bad=violation(periodic_counts(child,parent,N;limits))
    isnothing(bad) ? result("unknown","outside_hypotheses";checked_periods=N,kw...) : bad
end

function nilpotence(x::FixedShift,limits)
    n=length(x);n==0 && return 1
    p=fill(false,n,n);for i in 1:n;p[i,i]=true;end
    for exponent in 1:min(n,limits.max_power)
        p=boolean_multiply(x,p,xor)
        !any(p) && return exponent
    end
    n>limits.max_power && throw(ResourceLimit("nilpotence needs more than max_power"))
    0
end

# Matrix{Bool}, rather than BitMatrix: neighboring bits must not share writes.
function boolean_multiply(x::FixedShift,p::Matrix{Bool},op)
    n=length(x);out=fill(false,n,n)
    foreach_chunk(n;min_chunk=max(1,cld(16384,max(n,1)))) do columns,_
        for k in columns, i in 1:n, (j,_) in x.edges[i]
            out[i,k]=op(out[i,k],p[j,k])
        end
    end
    out
end
function parity_bound(l::Int)
    # Check H_r(q) only below the point where both trace terms vanish modulo 2^(r+1).
    checks=Tuple{Int,Int}[]
    for q in 1:2:l-1;push!(checks,(0,q));end
    r=1
    while true
        power=big(2)^r
        qmin=max(cld(big(l)*(r+1),power),cld(big(l)*r,power÷2))
        qmin<=1 && break
        for q in 1:2:Int(qmin)-1;push!(checks,(r,q));end
        r+=1
    end
    checks,r
end

# Exact dyadic enclosures of kth roots; no floating-point spectral estimates.
function root_floor(v::BigInt,k::Int;den=big(1024))
    target=v*den^k;lo=big(0);hi=den
    while hi^k<=target;hi*=2;end
    while hi-lo>1
        mid=(lo+hi)÷2
        mid^k<=target ? (lo=mid) : (hi=mid)
    end
    lo//den
end
root_upper(v,k;den=big(1024))=root_floor(v,k;den)+1//den
function row_step(x,v)
    [sum((v[j] for (j,_) in e);init=big(0)) for e in x.edges]
end
function growth_certificate(child,parent,limits)
    na=length(parent);nb=length(child)
    va=ones(BigInt,na);vb=ones(BigInt,nb)
    amin=BigInt[1];amax=BigInt[1];bmax=BigInt[nb==0 ? 0 : 1]
    chosen=nothing;best=nothing
    for k in 1:limits.max_power
        va=row_step(parent,va);vb=row_step(child,vb)
        push!(amin,minimum(va));push!(amax,maximum(va));push!(bmax,maximum(vb;init=big(0)))
    end
    candidates=Vector{NTuple{4,Rational{BigInt}}}(undef,limits.max_power)
    foreach_chunk(limits.max_power;min_chunk=16) do powers,_
        for k in powers
            local a,b,c,h
            den=big(1024)*nextpow(2,k)
            a=root_floor(amin[k+1],k;den);c=root_upper(amax[k+1],k;den)
            b=max(big(1)//1,root_upper(bmax[k+1],k;den))
            h=root_upper(numerator(c)*denominator(c),2;den)/denominator(c)
            candidates[k]=(a,b,c,h)
        end
    end
    for (k,(a,b,c,h)) in enumerate(candidates)
        # h encloses sqrt(c), including when c is non-integral.
        if a>1 && b<a && h<a && (isnothing(best) || max(b/a,h/a)<best)
            chosen=(k,a,b,c,h);best=max(b/a,h/a)
        end
    end
    isnothing(chosen) && throw(ResourceLimit("growth separation not certified within max_power"))
    k,a,b,c,h=chosen
    p=fill(false,na,na);for i in 1:na;p[i,i]=true;end
    s=0
    while !all(p)
        s+=1;s<=limits.max_power || throw(ResourceLimit("positive power exceeds max_power"))
        p=boolean_multiply(parent,p,|)
    end
    # s=0 is valid only for a 1x1 graph, where A^0 is strictly positive.
    U=na*maximum(amax[r+1]/c^r for r in 0:k-1)
    V=nb*maximum(bmax[r+1]/b^r for r in 0:k-1)
    L=na*minimum(amin[r+1]/a^r for r in 0:k-1)/a^s
    start=max(s,2,Int(cld(numerator(h/(a-h)),denominator(h/(a-h)))))
    # Bound speculative work: evaluating powers near max_period can be much
    # costlier than evaluating those near the first valid cutoff.
    for first in start:128:limits.max_period
        offset=first_match(min(128,limits.max_period-first+1);min_chunk=8,serial_prefix=0) do i
            local M=first+i-1
            V*(b/a)^M<=L/2 && M*U*(h/a)^M<=L/2
        end
        if !isnothing(offset)
            M=first+offset-1
            return (k=k,a=a,b=b,c=c,h=h,s=s,U=U,V=V,L=L,M=M)
        end
    end
    throw(ResourceLimit("quantity cutoff exceeds max_period"))
end

function check_cascade(child::FixedShift,parent::FixedShift;limits=Limits())
    guarded() do
        validate(limits)
        inclusion=check_inclusion(child,parent)
        inclusion["status"]=="true" || return result("false","not_included";inclusion=inclusion)
        check_inclusion(parent,child)["status"]=="true" && return result("false","equal_shifts")
        mixing=check_mixing(parent)
        positive=length(parent)>0 && any(e->length(e)>1,parent.edges) && mixing["status"]=="true"
        if mixing["status"]!="true" || !positive
            return outside_result(child,parent,limits;mixing=mixing,positive_entropy=positive)
        end
        la=nilpotence(parent,limits);lb=nilpotence(child,limits)
        (la==0 || lb==0) && return outside_result(child,parent,limits;
                                        parent_zeta_mod2=la>0,child_zeta_mod2=lb>0)
        l=max(la,lb);checks,stop_r=parity_bound(l)
        parity_N=maximum((Int(big(2)^r*q) for (r,q) in checks);init=0)
        parity_N<=limits.max_period || throw(ResourceLimit("parity cutoff exceeds max_period"))
        counts=periodic_counts(child,parent,parity_N;limits)
        for n in 1:parity_N
            modulus=big(2)^(trailing_zeros(n)+1)
            if counts.remaining[n]%modulus!=0
                return result("false","parity_violation";period=n,remaining=string(counts.remaining[n]),modulus=string(modulus))
            end
            counts.remaining[n]<0 && return result("false","quantity_violation";period=n,remaining=string(counts.remaining[n]))
        end
        cert=growth_certificate(child,parent,limits)
        N=max(parity_N,cert.M-1)
        counts=periodic_counts(child,parent,N;limits)
        for n in 1:N
            counts.remaining[n]<0 && return result("false","quantity_violation";period=n,remaining=string(counts.remaining[n]))
        end
        proof=Dict(string(key)=> (value isa Rational ? string(value) : value) for (key,value) in pairs(cert))
        proof["nilpotence_exponent"]=l;proof["parity_max_period"]=parity_N;proof["parity_stop_r"]=stop_r
        result("true","certified_cascade";certificate=proof,checked_periods=N,
               cascade_counts_through=min(N,32),
               cascade_counts=[string(counts.remaining[n]÷(2n)) for n in 1:min(N,32)])
    end
end

include("cli.jl")
end
