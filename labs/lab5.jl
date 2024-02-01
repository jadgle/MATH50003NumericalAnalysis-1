# # MATH50003 (2022–23)
# # Lab 5: III.1 Structured Matrices and III.2 Differential Equations


# In this lab we explore the construction of vectors and matrices, in particular those with sparsity structure
# such as triangular, diagonal, bidiagonal and tridiagonal
# which we capture using special types. We also explore the reduction of differential equations to
# banded linear systems via divided differences. When we get lower bidiagonal systems these can be solved
# using forward substitution, whereas we will discuss the tridiagonal case later.

# We first load  packages we need including a couple new ones:


## LinearAlgebra contains routines for doing linear algebra
## BenchmarkTools is a package for reliable timing
using LinearAlgebra, Plots, Test


# **Remark** One should normally not need to implement methods for solving differential equations
# oneself as there are packages available, including the high-performance
#  Julia package  [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl). Moreover Forward and Backward
# Euler are only the first baby steps to a wide range of time-steppers, with Runge–Kutta being
# one of the most successful.
# For example we can solve
# a simple differential equation like a pendulum $u'' = -\sin u$ can be solved
# as follows (writing at a system $u' = v, v' = -\sin u$):

using DifferentialEquations, LinearAlgebra, Plots

u = solve(ODEProblem((u,_,x) -> [u[2], -sin(u[1])], [1,0], (0,10)))
plot(u)

# However, even in these automated packages one has a choice of different methods with
# different behaviour, so it is important to understand on a mathematical level what is happening under the hood.


# **Learning Outcomes**
#
# Mathematical knowledge:
#
# 1. Matrix multiplication, back-substitution and forward-elimnation
# 2. Banded matrices and their utilisation for better complexity linear algebra.
# 2. Reduction of differential equations to bidiagonal or tridiagonal linear systems
# 3. Two-point boundary value problems
#
# Coding knowledge:
#
# 1. Construction of a dense `Vector` or `Matrix` either directly or via comprehensions or broadcasting
# 2. The `vec`, `transpose`, `zeros`, `ones`, `fill`, `promote_type`, and `eltype` functions.
# 3. Using `\` to solve linear systems.


# ## III.1 Structured Matrices

# Before discussing structured matrices we give an overview of creating arrays  (vectors and matrices)
# in Julia.

# ### III.1.1 Dense matrices


# One can create arrays in multiple ways. For example, the function `zeros(Int, 10)` creates
# a 10-element `Vector` whose entries are all `zero(Int) == 0`. Or `fill(x, 10)` creates a
# 10-element `Vector` whose entries are all equal to `x`. Or you can use a comprehension:
# for example `[k^2 for k = 1:10]` creates a vector whose entries are `[1^2, 2^2, …, 10^2]`.
# This also works for matrices: `zeros(Int, 10, 5)` creates a 10 × 5 matrix of all zeros,
# and `[k^2 + j for k=1:3, j=1:4]` creates the following:

[k^2 + j for k=1:3, j=1:4] # k is the row, j is the column

# Note sometimes it is best to create a vector/matrix and populate it. For example, the
# previous matrix could also been constructed as follows:

A = zeros(Int, 3, 4) # create a 3 × 4 matrix whose entries are `Int`
for k = 1:3, j = 1:4
    A[k,j] = k^2 + j # set the entries of A
end
A

# **Remark** Julia uses 0-based indexing where the first index of a vector/matrix
# is 1. This is standard in all mathematical programming languages (Fortran, Maple, Matlab, Mathematica)
# whereas those designed for computer science use 0-based indexing (C, Python, Rust).



# Be careful: a `Matrix` or `Vector` can only ever contain entries of the right
# type. It will attempt to convert an assignment to the right type but will throw
# an error if not successful:

A[2,3] = 2.0 # works because 2.0 is a Float64 that is exactly equal to an Int
A[1,2] = 2.3 # fails since 2.3 is a Float64 that cannot be converted to an Int


# ------
# **Problem 1(a)** Create a 5×6 matrix whose entries are `Int` which is
# one in all entries. Hint: use a for-loop, `ones`, `fill`, or a comprehension.
## TODO: Create a matrix of ones, 4 different ways


# **Problem 1(b)** Create a 1 × 5 `Matrix{Int}` with entries `A[k,j] = j`. Hint: use a for-loop or a comprehension.

## TODO: Create a 1 × 5  matrix whose entries equal the column, 2 different ways


# -------
# #### Transposes and adjoints

# We can also transpose a matrix `A`, This is done lazily
# and so `transpose(A)` (which is equivalent to the adjoint/conjugate-transpose
# `A'` when the entries are real),
# is just a special type with a single field: `transpose(A).parent == A`.
# This is equivalent to
# _row-major_ format, where the next address in memory of `transpose(A)` corresponds to
# moving along the row.


# #### Broadcasting

# _Broadcasting_ is a powerful and convenient way to create matrices or vectors,
# where a function is applied to every entry of a vector or matrix.
# By adding `.` to the end of a function we "broadcast" the function over
# a vector:

x = [1,2,3]
cos.(x) # equivalent to [cos(1), cos(2), cos(3)], or can be written broadcast(cos, x)

# Broadcasting has some interesting behaviour for matrices.
# If one dimension of a matrix (or vector) is 1, it automatically
# repeats the matrix (or vector) to match the size of another example.
# In the following we use broadcasting to pointwise-multiply a column and row
# vector to make a matrix:

[1,2,3] .* [4,5]'

# Since `size([1,2,3],2) == 1` it repeats the same vector to match the size
# `size([4,5]',2) == 2`. Similarly, `[4,5]'` is repeated 3 times. So the
# above is equivalent to:

[1 1; 2 2; 3 3] .* [4 5; 4 5; 4 5]

# Note we can also use matrix broadcasting with our own functions:

f = (x,y) -> cos(x + 2y)
f.([1,2,3], [4,5]') # makes a matrix with entries [f(1,4) f(1,5); f(2,4) f(2,5); f(3,4) f(3.5)]


# #### Ranges

# _Ranges_ are another useful example of vectors.
# We have already seen that we can represent a range of integers via `a:b`. Note we can
# convert it to a `Vector` as follows:

Vector(2:6)

# We can also specify a step:

Vector(2:2:6), Vector(6:-1:2)

# Finally, the `range` function gives more functionality, for example, we can create 4 evenly
# spaced points between `-1` and `1`:

Vector(range(-1, 1; length=4))

# Note that `Vector` is mutable but a range is not:

r = 2:6
r[2] = 3   # Not allowed

# Both ranges `Vector` are subtypes of `AbstractVector`, whilst `Matrix` is a subtype of `AbstractMatrix`.


# -----

# **Problem 1(c)** Create a vector of length 5 whose entries are `Float64`
# approximations of `exp(-k)`. Hint: use a for-loop, broadcasting `f.(x)` notation, or a comprehension.
## TODO: Create a vector whose entries are exp(-k), 3 different ways



# ------
# #### Storage of matrices and vectors

# A `Vector` stores its entries consecutively in memory.
# To be perhaps overly technical: a `Vector` contains a "pointer" (an integer)
# to the first memory address and a length. A `Matrix` is also stored consecutively in memory
#  going down column-by-
# column (_column-major_). That is,

A = [1 2;
     3 4;
     5 6]

# Is actually stored equivalently to a length `6` vector `[A[1,1],A[2,1],A[3,1],A[1,2],A[2,2],A[3,2]]`:

vec(A)

# which in this case would be stored using `8 * 6 = 48` consecutive bytes.
# Behind the scenes, a matrix is also "pointer" to the location of the first entry alongside two integers
# dictating the row and column sizes.


# Matrix-vector multiplication works as expected because `*` is overloaded:

x = [7, 8]
A * x


# We can implement our own version for any types that support `*` and `+` but there are
# actually two different ways. The most natural mathematical way is as follows:

function mul_rows(A, x)
    m,n = size(A)
    ## promote_type type finds a type that is compatible with both types, eltype gives the type of the elements of a vector / matrix
    T = promote_type(eltype(x), eltype(A))
    c = zeros(T, m) # the returned vector, begins of all zeros
    for k = 1:m # for each column
        for j = 1:n # then each row
            c[k] += A[k, j] * x[j] # equivalent to c[k] = c[k] + A[k, j] * x[j]
        end
    end
    c
end


# But we can also change the order of operations to give an alternative approach:

function mul_cols(A, x)
    m,n = size(A)
    ## promote_type type finds a type that is compatible with both types, eltype gives the type of the elements of a vector / matrix
    T = promote_type(eltype(x), eltype(A))
    c = zeros(T, m) # the returned vector, begins of all zeros
    for j = 1:n # for each column
        xⱼ = x[j]
        for k = 1:m # then each row
            c[k] += A[k, j] * xⱼ # equivalent to c[k] = c[k] + A[k, j] * x[j]
        end
    end
    c
end


# Both implementations match _exactly_ for integer inputs:

mul_rows(A, x), mul_cols(A, x) # also matches `A*x`


# Either implementation will be $O(mn)$ operations. However, the implementation
# `mul_cols` accesses the entries of `A` going down the column,
# which happens to be _significantly faster_ than `mul_rows`, due to accessing
# memory of `A` in order. We can see this by measuring the time it takes using `@btime`:

n = 1000
A = randn(n,n) # create n x n matrix with random normal entries
x = randn(n) # create length n vector with random normal entries

using BenchmarkTools # load package for reliable timing
@btime mul_rows(A,x)
@btime mul_cols(A,x)
@btime A*x; # built-in, high performance implementation. USE THIS in practice

# Here `ms` means milliseconds (`0.001 = 10^(-3)` seconds) and `μs` means microseconds (`0.000001 = 10^(-6)` seconds).
# So we observe that `mul` is roughly 3x faster than `mul_rows`, while the optimised `*` is roughly 5x faster than `mul`.
# The reason why isn't too important for us (accessing memory in order is much faster than jumping around), but the key points are:
# 1. Making fast algorithms is delicate and arguably more of an art than a science.
# 2. We can focus on complexity rather than counting operations as the latter does not tell us speed.
# 3. Use in-built implementations whenever available.


# Note that the rules of floating point arithmetic apply here: matrix multiplication with floats
# will incur round-off error (the precise details of which are subject to the implementation):


A = [1.4 0.4;
     2.0 1/2]
A * [1, -1] # First entry has round-off error, but 2nd entry is exact

# And integer arithmetic will be subject to overflow:

A = fill(Int8(2^6), 2, 2) # make a matrix whose entries are all equal to 2^6
A * Int8[1,1] # we have overflowed and get a negative number -2^7

# Solving a linear system is done using `\`:

A = [1 2 3;
     1 2 4;
     3 7 8]
b = [10; 11; 12]
A \ b

# Despite the answer being integer-valued,
# here we see that it resorted to using floating point arithmetic,
# incurring rounding error.
# But it is "accurate to (roughly) 16-digits".
# As we shall see, the way solving a linear system works is we first write `A` as a
# product of matrices that are easy to invert, e.g., a product of triangular matrices or a product of an orthogonal
# and triangular matrix.


# The following problem compares the behaviour of `mul_cols` defined in lectures
# to the inbuilt matrix-vector multiplication operation `A*x`. The point is that
# sometimes the choice of algorithm, despite being mathematically equivalent, can change the exact results
# when using floating point.

# ### III.1.2 Triangular Matrices

# Triangular matrices are represented by dense square matrices where the entries below the
# diagonal are ignored:

A = [1 2 3;
     4 5 6;
     7 8 9]
L = LowerTriangular(A)

# We can see that `L` is storing all the entries of `A` in a field called `data`:

L.data

# Similarly we can create an upper triangular matrix by ignoring the entries below the diagonal:

U = UpperTriangular(A)

# If we know a matrix is triangular we can do matrix-vector multiplication in roughly half
# the number of operations by skipping over the entries we know are zero:

function mul_cols(L::LowerTriangular, x)
    n = size(L,1)
    ## promote_type type finds a type that is compatible with both types, eltype gives the type of the elements of a vector / matrix
    T = promote_type(eltype(x),eltype(L))
    b = zeros(T, n) # the returned vector, begins of all zeros
    for j = 1:n
        xⱼ = x[j]
        for k = j:n # k = j:n instead of 1:n since we know L[k,j] = 0 if k < j.
            b[k] += L[k, j] * xⱼ
        end
    end
    b
end

x = [10, 11, 12]
## matches built-in * which also exploits the structure:
@test mul_cols(L, x) == L*x


# Moreover, we can easily invert matrices.
# Consider a simple 3×3 example, which can be solved with `\`:

b = [5, 6, 7]
x = L \ b # Excercise: why does this return a float vector?

# Behind the seens, `\` is doing forward-elimination.
# We can implement our own version for any types that support `*`, `+` and `/` as follows:


function ldiv(L::LowerTriangular, b)
    n = size(L,1)

    if length(b) != n
        error("The system is not compatible")
    end

    x = zeros(n)  # the solution vector
    for k = 1:n  # start with k = 1
        r = b[k]  # dummy variable
        for j = 1:k-1
            r -= L[k,j]*x[j]
        end
        x[k] = r/L[k,k]
    end
    x
end


@test ldiv(L, b) ≈ L\b



# ------

# **Problem 3(a)** Complete the following function for upper triangular matrix-vector
# multiplication without ever accessing the zero entries of `L` above the diagonal.
# Hint: just copy code for `mul_cols` and modify the for-loop ranges a la the `UpperTriangular`
# case.

function mul_cols(U::UpperTriangular, x)
    n = size(U,1)

    ## promote_type type finds a type that is compatible with both types, eltype gives the type of the elements of a vector / matrix
    T = promote_type(eltype(x),eltype(U))
    b = zeros(T,n) # the returned vector, begins of all zeros

    ## TODO: populate b so that U*x ≈ b
    

    b
end

U = UpperTriangular(randn(5,5))
x = randn(5)
@test U*x ≈ mul_cols(L, x)


# **Problem 3(b)** Complete the following function for solving linear systems with
# upper triangular systems by implementing back-substitution. You may assume
# all input and output vectors have `Float64` values.

## ldiv(U, b) is our implementation of U\b
function ldiv(U::UpperTriangular, b)
    n = size(U,1)

    if length(b) != n
        error("The system is not compatible")
    end

    x = zeros(n)  # the solution vector
    ## TODO: populate x with the entries according to back substitution.
    
    x
end


U = UpperTriangular(randn(5,5))
b = randn(5)
@test U\b ≈ ldiv(U, b)


# ## III.1.3 Banded matrices


# Diagonal matrices in Julia are stored as a vector containing the diagonal entries:

x = [1,2,3]
D = Diagonal(x) # the type Diagonal has a single field: D.diag

# It is clear that we can perform diagonal-vector multiplications and solve linear systems involving diagonal matrices efficiently
# (in $O(n)$ operations).


# We can create Bidiagonal matrices in Julia by specifying the diagonal and off-diagonal:


L = Bidiagonal([1,2,3], [4,5], :L) # the type Bidiagonal has three fields: L.dv (diagonal), L.ev (lower-diagonal), L.uplo (either 'L', 'U')
##
Bidiagonal([1,2,3], [4,5], :U)


# Multiplication and solving linear systems with Bidiagonal systems is also $O(n)$ operations, using the standard
# multiplications/back-substitution algorithms but being careful in the loops to only access the non-zero entries.


# Julia has a type `Tridiagonal` for representing a tridiagonal matrix from its sub-diagonal, diagonal, and super-diagonal:

T = Tridiagonal([1,2], [3,4,5], [6,7]) # The type Tridiagonal has three fields: T.dl (sub), T.d (diag), T.du (super)

# Tridiagonal matrices will come up in solving second-order differential equations and orthogonal polynomials.
# We will later see how linear systems involving tridiagonal matrices can be solved in $O(n)$ operations.



# -----

# **Problem 4(a)** Complete the implementation of `UpperTridiagonal` which represents a banded matrix with
# bandwidths $(l,u) = (0,2)$ by overloading `getindex(U::UpperTridiagonal, k::Int, j::Int)` (which implements `U[k,j]`) and `setindex!(U::UpperTriangular, v, k::Int, j::Int)` (which implements `U[k,j] = v`). Return zero (of the same type as the other entries)
# if we are off the bands.

struct UpperTridiagonal{T} <: AbstractMatrix{T}
    d::Vector{T}   # diagonal entries: d[k] == U[k,k]
    du::Vector{T}  # super-diagonal enries: du[k] == U[k,k+1]
    du2::Vector{T} # second-super-diagonal entries: du2[k] == U[k,k+2]
end

## This uses the notation `<: AbstractMatrix{T}`: this tells Julia that our type is in fact a matrix.
## In order for it to behave a matrix we have to overload the function `size` for our type to return
## the dimensions (in this case we just use the length of the diagonal):

import Base: size, getindex

size(U::UpperTridiagonal) = (length(U.d),length(U.d))

## Julia still doesn't know what the entries of the matrix are. To do this we need to overload `getindex`.
## We also overload `setindex!` to allow changing the non-zero entries.


## getindex(U, k, j) is another way to write U[k,j].
## This function will therefore be called when we call U[k,j]
function getindex(U::UpperTridiagonal, k::Int, j::Int)
    d,du,du2 = U.d,U.du,U.du2
    ## TODO: return U[k,j]
    
end

## setindex!(U, v, k, j) gets called when we write (U[k,j] = v).
function setindex!(U::UpperTridiagonal, v, k::Int, j::Int)
    d,du,du2 = U.d,U.du,U.du2
    if j > k+2 || j < k
        error("Cannot modify off-band")
    end

    ## TODO: modify d,du,du2 so that U[k,j] == v
    
    U # by convention we return the matrix
end

U = UpperTridiagonal([1,2,3,4,5], [1,2,3,4], [1,2,3])
@test U == [1 1 1 0 0;
            0 2 2 2 0;
            0 0 3 3 3;
            0 0 0 4 4;
            0 0 0 0 5]

U[3,4] = 2
@test U == [1 1 1 0 0;
            0 2 2 2 0;
            0 0 3 2 3;
            0 0 0 4 4;
            0 0 0 0 5]




# **Problem 4(b)** Complete the following implementations of `*` and `\` for `UpperTridiagonal` so that
# they take only $O(n)$ operations. Hint: the function `max(a,b)` returns the larger of `a` or `b`
# and `min(a,b)` returns the smaller. They may help to avoid accessing zeros.

function *(U::UpperTridiagonal, x::AbstractVector)
    n = size(U,1)
    ## promote_type type finds a type that is compatible with both types, eltype gives the type of the elements of a vector / matrix
    T = promote_type(eltype(x),eltype(U))
    b = zeros(T, n) # the returned vector, begins of all zeros
    ## TODO: populate b so that U*x ≈ b (up to rounding)
    
    b
end

function \(U::UpperTridiagonal, b::AbstractVector)
    n = size(U,1)
    T = promote_type(eltype(b),eltype(U))

    if length(b) != n
        error("The system is not compatible")
    end

    x = zeros(T, n)  # the solution vector
    ## TODO: populate x so that U*x ≈ b
    
    x
end

n = 1_000_000 # under-scores are like commas: so this is a million: 1,000,000
U = UpperTridiagonal(ones(n), fill(0.5,n-1), fill(0.1,n-2))
x = ones(n)
b = [fill(1.6,n-2); 1.5; 1] # exact result
## note following should take much less than a second
@test U*x ≈ b
@test U\b ≈ x



#-----


# ## III.2 Differential Equations via Finite Differences

# We now turn to an important application of banded linear algebra:
# approximating solutions to linear differential equations. We will focus on first and second order
# but the techniques generalise beyond this, to vector problems, nonlinear differential equations, and partial differential equations.

# We explore _finite difference_ approxiamtions which use divided differences to replace derivatives.
# These are the most basic type of numerical method and many powerful alternatives
# exist, including Finite Element Methods and spectral methods.


# ### III.2.1 Indefinite integration

# We can use the right-sided divided difference to approximate derivatives.  Let's do an example of integrating $\cos x$ by discretising the ODE
# $$
#  u'(x) = f(x), u(0) = c
# $$
# as
# and see if our method matches
# the true answer of $\sin x$. Recall from the notes that this equation can be approximated by $u_k$ solving the bidiagonal linear system
# $$
# \begin{bmatrix}
#     1 \\ 
#     -1/h & 1/h \\
#     & ⋱ & ⋱ \\
#     && -1/h & 1/h \end{bmatrix} \Vectt[u_0,u_1,⋮,u_n] = \Vectt[c, f(x_0), f(x_1), ⋮ , f(x_{n-1})].
# $$
# We can construct the bidiagonal matrix as follows:

n = 10
x = range(0, 1; length=n+1) # makes an n+1 point evenly spaced grid
h = step(x) # equivalent to 1/n
L = Bidiagonal([1; fill(1/h, n)], fill(-1/h, n), :L)

# We can use this bidiagonal matrix along with `\` to solve the
# system via Forward elimination:

c = 0 # u(0) = 0
f = x -> cos(x)

𝐟 = f.(x[1:end-1]) # evaluate f at all but the last point
𝐮 = L \ [c; 𝐟] # integrate using forward-differences

plot(x, sin.(x); label="sin(x)", legend=:bottomright)
scatter!(x, 𝐮ᶠ; label="forward")


#  We can estimate how fast it converges by measuring
# the ∞-norm error (using $\| 𝐱 \|_∞ := \max |x_k|$ which
# is implemented as `norm(x,Inf)`):

## Error from indefinite integration with c and f
function forward_err(u, c, f, n)
    x = range(0, 1; length = n+1)
    h = step(x) # equivalent to 1/n
    L = Bidiagonal([1; fill(1/h, n)], fill(-1/h, n), :L)
    𝐮 = L\ [c; f.(x[1:end-1])]
    errs = 𝐮 - u.(x) # compare numerics with "true" result
    norm(errs, Inf) # measure ∞-norm error
end


ns = 10 .^ (1:8) # solve up to n = 10 million
scatter(ns, forward_err.(sin, 0, f, ns); xscale=:log10, yscale=:log10, label="forward")
plot!(ns, ns .^ (-1); label="1/n")

# We see that the method converges linearly (like $O(n^{-1})$). 

# ------

# **Problem 5(a)** Implement Backward Euler as derived in the problem sheet to approximate
# indefinite-integration. How does the error compare to forward
# for $f(x) = \cos x$ on the interval $[0,1]$?
# Use the method to approximate the indefinite intergral of
# $$
# \exp(\exp x \cos x + \sin x)
# $$
# to 3 digits.

## TODO: Implement Backward Euler by constructing a lower bidiagonal linear system.


# **Problem 5(b)** Implement indefinite-integration
# where we impose the equation on the midpoints $m_1,…,m_n$ defined as
# $$
# m_j = (x_{j+1} + x_j)/2 = a + (j+1/2)h
# $$
# using the central difference formula
# $$
# u'(m_j) ≈ {u(x_j) - u(x_{j-1}) \over h}
# $$
# By plotting the errors show that this method converges at
# a faster rate than Forward or Backward Euler for $f(x) = \cos x$ on the interval $[0,1]$.


## TODO:


# ----

# ### III.2.2 Forward Euler


# Here is a simple example for solving:
#     $$
#     u'(0) = 1, u' + t u = {\rm e}^t
#     $$
#     which has an exact solution in terms of a special error function
#     (which we determined using Mathematica).


using SpecialFunctions
c = 1
a = t -> t
n = 2000
t = range(0, 1; length=n)
## exact solution, found in Mathematica
u = t -> -(1/2)*exp(-(1+t^2)/2)*(-2sqrt(ℯ) + sqrt(2π)erfi(1/sqrt(2)) - sqrt(2π)erfi((1 + t)/sqrt(2)))

h = step(t)
L = Bidiagonal([1; fill(1/h, n-1)], a.(t[1:end-1]) .- 1/h, :L)

norm(L \ [c; exp.(t[1:end-1])] - u.(t),Inf)

# We see that it is converging to the true result.

# ---- 


# **Problem  6** Implement backward Euler for solving:
# $$
# \begin{align*}
# u(0) &= 1, u'(t) - \cos(t) u(t) = t
# \end{align*}
# $$
# If we increase the initial condition $w(0) = c > 1$, $w'(0)$
# the solution may blow up in finite time. Find the smallest positive integer $c$
# such that the numerical approximation suggests the equation
# does not blow up.





# ### III.2.3 Poisson equation

# Thus we solve:

x = range(0, 1; length = n)
h = step(x)
T = Tridiagonal([fill(1/h^2, n-2); 0], [1; fill(-2/h^2, n-2); 1], [0; fill(1/h^2, n-2)])
u = T \ [1; exp.(x[2:end-1]); 2]
scatter(x, u)


# We can test convergence on $u(x) = \cos x^2$ which satisfies
# $$
# \begin{align*}
# u(0) = 1 \\
# u(1) = \cos 1 \\
# u''(x) = -4x^2 \cos(x^2) - 2\sin(x^2)
# \end{align*}
# $$
# We observe uniform ($∞$-norm) convergence:

function poisson_err(u, c_0, c_1, f, n)
    x = range(0, 1; length = n)
    h = step(x)
    T = Tridiagonal([fill(1/h^2, n-2); 0], [1; fill(-2/h^2, n-2); 1], [0; fill(1/h^2, n-2)])
    uᶠ = T \ [c_0; f.(x[2:end-1]); c_1]
    norm(uᶠ - u.(x), Inf)
end

u = x -> cos(x^2)
f = x -> -4x^2*cos(x^2) - 2sin(x^2)

ns = 10 .^ (1:8) # solve up to n = 10 million
scatter(ns, poisson_err.(u, 1, cos(1), f, ns); xscale=:log10, yscale=:log10, label="error")
plot!(ns, ns .^ (-2); label="1/n^2")


# **Problem 7** Construct a finite-difference approximation to the
# forced Helmholtz equation
# $$
# \begin{align*}
# u(0) &= 0 \\
# u(1) &= 0 \\
# u'' + k^2 u &= {\rm e}^x
# \end{align*}
# $$
# and find an $n$ such  the error is less than $10^{-4}$ when compared
# with the true solution for $k=10$:
# $$
# u(x) = (-\cos(k x) + {\rm e}^x \cos(k x)^2 + \cot(k) \sin(k x) - {\rm e} \cos(k) \cot(k) \sin(k x) - {\rm e} \sin(k) \sin(k x) + {\rm e}^x \sin(k x)^2)/(1 + k^2)
# $$




# **Problem 8** Discretisations can also be used to solve eigenvalue problems.
# Consider the Schrödinger equation with quadratic oscillator:
# $$
# u(-L) = u(L) = 0, -u'' + x^2 u = λ u
# $$
# (a) Use the finite-difference approximation to discretise this equation as eigenvalues of a
# matrix. Hint: write
# $$
# \begin{align*}
# u(-L) = 0 \\
# -u'' + x^2 u - λu = 0\\
# u(L) = 0
# \end{align*}
# $$
# and discretise as before, doing row eliminations to arrive at a symmetric tridiagonal
# matrix eigenvalue problem.
# (b) Approximate the eigenvalues using `eigvals(A)` (which returns the eigenvalues of a
# matrix `A`) with $L = 10$.
# Can you conjecture their exact value if $L = ∞$? Hint: they are integers and the eigenvalues
# closest to zero are most accurate.

## SOLUTION
# We discretise on a grid $u_1,u_2,…,u_n$ for an evenly spaced grid between $[-L,L]$, with
# step size $h = 2L/(n-1)$. That is, we have the equations:
# $$
# \begin{bmatrix}
# 1 \\
# -1/h^2 & 2/h^2 + x_2^2  - λ & -1/h^2 \\
#     & ⋱ & ⋱ & ⋱ \\
#     && -1/h^2 &  2/h^2 + x_{n-1}^2  - λ & -1/h^2 \\
#     &&&& 1 \end{bmatrix}
#     \begin{bmatrix} u_1 \\ \vdots \\ u_n \end{bmatrix} = 0
# $$
# Row eliminations at the top and bottom reduce this equation to:
# $$
# \begin{bmatrix}
#  2/h^2 + x_2^2   & -1/h^2 \\
#     & ⋱ & ⋱ & ⋱ \\
#     && -1/h^2 &  2/h^2 + x_{n-1}^2   \end{bmatrix}
#     \begin{bmatrix} u_2 \\ \vdots \\ u_{n-1} \end{bmatrix} = λ\begin{bmatrix} u_2 \\ \vdots \\ u_{n-1} \end{bmatrix}
# $$
# This is a standard eigenvalue problem and we can compute the eigenvalues using `eigvals`:

L = 10
n = 1000
x = range(-L,L; length=n)
h = step(x)
eigvals(SymTridiagonal(fill(2/h^2,n-2)  + x[2:end-1].^2, fill(-1/h^2, n-3)))


# On inspection of the smallest values, it seems that the positive odd integers are the eigenvalues for $L = \infty$. Increasing $L$ (and also $n$) it becomes more obvious:

L = 100
n = 10000
x = range(-L,L; length = n)
h = step(x)
A = SymTridiagonal(x[2:end-1] .^ 2 .+ 2/h^2,ones(n-3)* (-1)/h^2)
sort((eigvals(A)))[1:20]

