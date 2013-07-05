# Helper for CMAKE to use the correct toolchain

include(CMakeForceCompiler)
# Prefix detection only works with compiler id "GNU"
# CMake will look for prefixed g++, cpp, ld, etc. automatically
CMAKE_FORCE_C_COMPILER(arm-none-linux-gnueabi-gcc GNU)
CMAKE_FORCE_CXX_COMPILER(arm-none-linux-gnueabi-g++ GNU)

