cmake_minimum_required(VERSION 3.21)
project(capfixture CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

enable_testing()
add_executable(tests capfixture_test.cpp)
target_include_directories(tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Registered by hand rather than via doctest_discover_tests: the ctest test
# names must equal the TEST_CASE names for neotest-ctest to map a result back
# to a position in the source, and doing it here keeps the fixture to two
# files with no generated helper script.
add_test(NAME passes COMMAND tests --test-case=passes)
add_test(NAME fails  COMMAND tests --test-case=fails)
