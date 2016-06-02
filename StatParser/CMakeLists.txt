cmake_minimum_required(VERSION 3.3)

project(StatParser CXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON )

SET(BOOST_INCLUDEDIR /p/gat/tools/boost/1.55.0/include/)
SET(BOOST_LIBRARYDIR /p/gat/tools/boost/1.55.0/gcc4.8/lib64/)

set(Boost_USE_STATIC_LIBS        ON) # only find static libs
set(Boost_USE_MULTITHREADED      ON)
find_package(Boost COMPONENTS regex iostreams zlib REQUIRED)

include_directories(${Boost_INCLUDE_DIRS})

add_executable(StatParser 
               ExprParser.cpp
               StatParser.cpp
              )

target_link_libraries(StatParser
                     ${Boost_LIBRARIES}
                   )
