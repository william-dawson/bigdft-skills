!> Test driver: Memory allocation and profiling
!! Exercises f_malloc, f_free, f_malloc0, f_routine, and f_zero.
program test_memory
  use futile
  implicit none

  real(f_double), dimension(:), allocatable :: vec
  real(f_double), dimension(:,:), allocatable :: mat
  integer, dimension(:), allocatable :: ivec
  integer(f_long) :: t0, t1
  integer :: i
  real(f_double) :: checksum

  call f_lib_initialize()

  call yaml_mapping_open('Memory Allocation Tests')

  ! --- Basic allocation ---
  call f_routine(id='basic_alloc')
  vec = f_malloc(1000, id='vec')
  do i = 1, 1000
    vec(i) = real(i, f_double)
  end do
  call yaml_map('Vec sum', sum(vec))
  call yaml_map('Vec size', size(vec))
  call f_free(vec)
  call f_release_routine()

  ! --- Zero-initialized allocation ---
  call f_routine(id='zero_alloc')
  ivec = f_malloc0(500, id='ivec')
  call yaml_map('Zero-init sum', sum(ivec))
  call f_free(ivec)
  call f_release_routine()

  ! --- Multi-dimensional ---
  call f_routine(id='matrix_alloc')
  mat = f_malloc((/100, 200/), id='mat')
  call yaml_map('Mat shape', (/size(mat, 1), size(mat, 2)/))
  call f_free(mat)
  call f_release_routine()

  ! --- f_zero performance ---
  call f_routine(id='zero_perf')
  vec = f_malloc(100000, id='perf_vec')
  t0 = f_time()
  do i = 1, 100
    call f_zero(vec)
  end do
  t1 = f_time()
  call yaml_map('f_zero 100x100k (s)', real(t1 - t0, f_double) * 1.d-9)
  call yaml_map('Sum after zero', sum(vec))
  call f_free(vec)
  call f_release_routine()

  call yaml_mapping_close()

  call f_lib_finalize()
end program test_memory
