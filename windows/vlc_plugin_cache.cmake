# Generates libVLC's plugins.dat for the bundled VLC runtime.
#
# Run in script mode:
#   cmake -DVLC_RUNTIME_SEARCH_DIR=<dir> -DBUNDLE_PLUGINS_DIR=<dir>
#         -P vlc_plugin_cache.cmake
#
# Why this matters, and why it is worth the seconds it costs:
#
# Without a valid cache, libvlc_new() rebuilds its module bank and logs one
# "stale plugins cache: modified ..." error per plugin -- ~730 lines. vlc_player
# creates its instance synchronously on the Flutter platform thread, and VLC
# writes those lines to stderr. Under `flutter run` stderr is a pipe drained by
# the Flutter tool, and once the pipe buffer fills, the write blocks. Measured
# on this project: 248 ms with a fast stderr reader, 21,267 ms with a slow one.
# That is a 21-second whole-app freeze on the first video of each run.
#
# Getting the ordering right is the hard part. The vlc_player plugin copies its
# plugins/ directory with cmake -E copy_directory, which re-stamps every DLL's
# mtime on every build, and libVLC validates the cache against those mtimes. The
# copy targets are ALL-targets that INSTALL does not reference, so MSBuild runs
# them concurrently with this script and a cache written mid-copy is rejected.
# add_dependencies does not help; neither does running as an install step.
#
# So instead of assuming an order, wait for the copy to go quiet, then verify
# the result and retry if it was still moving. Never fails the build: a missing
# cache only costs startup time.

if(NOT IS_DIRECTORY "${BUNDLE_PLUGINS_DIR}")
  message(STATUS
    "vlc_plugin_cache: no plugins directory at ${BUNDLE_PLUGINS_DIR}, skipping.")
  return()
endif()

# The VLC runtime is downloaded into a version-stamped directory, so discover
# the generator rather than pinning a version.
file(GLOB VLC_CACHE_GEN_CANDIDATES
  "${VLC_RUNTIME_SEARCH_DIR}/*/vlc-cache-gen.exe")
if(NOT VLC_CACHE_GEN_CANDIDATES)
  message(STATUS
    "vlc_plugin_cache: vlc-cache-gen.exe not found under "
    "${VLC_RUNTIME_SEARCH_DIR}, skipping.")
  return()
endif()
list(GET VLC_CACHE_GEN_CANDIDATES 0 VLC_CACHE_GEN)
get_filename_component(VLC_RUNTIME_DIR "${VLC_CACHE_GEN}" DIRECTORY)

set(VLC_PLUGIN_CACHE_FILE "${BUNDLE_PLUGINS_DIR}/plugins.dat")

# Newest mtime across every bundled plugin, as a sortable string.
macro(vlc_newest_plugin_time out_var)
  file(GLOB_RECURSE _vlc_plugin_dlls "${BUNDLE_PLUGINS_DIR}/*.dll")
  set(${out_var} "")
  foreach(_vlc_plugin_dll ${_vlc_plugin_dlls})
    file(TIMESTAMP "${_vlc_plugin_dll}" _vlc_plugin_dll_time UTC)
    if("${_vlc_plugin_dll_time}" STRGREATER "${${out_var}}")
      set(${out_var} "${_vlc_plugin_dll_time}")
    endif()
  endforeach()
endmacro()

if(EXISTS "${VLC_PLUGIN_CACHE_FILE}")
  file(TIMESTAMP "${VLC_PLUGIN_CACHE_FILE}" VLC_PLUGIN_CACHE_TIME UTC)
  vlc_newest_plugin_time(VLC_PLUGIN_NEWEST_TIME)
  # file(TIMESTAMP) resolves to whole seconds, so equal timestamps cannot be
  # told apart -- a cache written mid-copy shares its second with the plugins
  # copied just after it. Treat equal as stale and require a strict gap.
  if("${VLC_PLUGIN_CACHE_TIME}" STRGREATER "${VLC_PLUGIN_NEWEST_TIME}")
    return()
  endif()
endif()

set(VLC_PLUGIN_CACHE_ROUND 0)
while(VLC_PLUGIN_CACHE_ROUND LESS 3)
  # Wait until the copy stops touching files.
  vlc_newest_plugin_time(VLC_PLUGIN_SETTLE_PREVIOUS)
  set(VLC_PLUGIN_SETTLE_TRIES 0)
  while(VLC_PLUGIN_SETTLE_TRIES LESS 20)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)
    vlc_newest_plugin_time(VLC_PLUGIN_SETTLE_CURRENT)
    if("${VLC_PLUGIN_SETTLE_CURRENT}" STREQUAL "${VLC_PLUGIN_SETTLE_PREVIOUS}")
      break()
    endif()
    set(VLC_PLUGIN_SETTLE_PREVIOUS "${VLC_PLUGIN_SETTLE_CURRENT}")
    math(EXPR VLC_PLUGIN_SETTLE_TRIES "${VLC_PLUGIN_SETTLE_TRIES}+1")
  endwhile()

  # file(TIMESTAMP) has one-second resolution, so put a clear second between
  # the last copy and the cache rather than relying on sub-second ordering.
  execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1)

  message(STATUS "vlc_plugin_cache: generating ${VLC_PLUGIN_CACHE_FILE}")
  file(REMOVE "${VLC_PLUGIN_CACHE_FILE}")

  # vlc-cache-gen only indexes anything when VLC_PLUGIN_PATH points at the same
  # directory it is given -- with the argument alone it writes an empty 24-byte
  # cache. This must match the path the plugin sets at runtime.
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
      "VLC_PLUGIN_PATH=${BUNDLE_PLUGINS_DIR}"
      "${VLC_CACHE_GEN}" "${BUNDLE_PLUGINS_DIR}"
    WORKING_DIRECTORY "${VLC_RUNTIME_DIR}"
    RESULT_VARIABLE VLC_PLUGIN_CACHE_RESULT
    OUTPUT_VARIABLE VLC_PLUGIN_CACHE_OUTPUT
    ERROR_VARIABLE VLC_PLUGIN_CACHE_OUTPUT)

  if(NOT VLC_PLUGIN_CACHE_RESULT EQUAL 0 OR
     NOT EXISTS "${VLC_PLUGIN_CACHE_FILE}")
    message(WARNING
      "vlc_plugin_cache: vlc-cache-gen failed (${VLC_PLUGIN_CACHE_RESULT}); the "
      "first video of each run will freeze the app. ${VLC_PLUGIN_CACHE_OUTPUT}")
    return()
  endif()

  file(TIMESTAMP "${VLC_PLUGIN_CACHE_FILE}" VLC_PLUGIN_CACHE_TIME UTC)
  vlc_newest_plugin_time(VLC_PLUGIN_NEWEST_TIME)
  if("${VLC_PLUGIN_CACHE_TIME}" STRGREATER "${VLC_PLUGIN_NEWEST_TIME}")
    return()
  endif()

  # A plugin was written after the cache: the copy was still running. Retry.
  math(EXPR VLC_PLUGIN_CACHE_ROUND "${VLC_PLUGIN_CACHE_ROUND}+1")
endwhile()

message(WARNING
  "vlc_plugin_cache: plugins kept changing under the cache generator; run "
  "tool/refresh_vlc_cache.ps1 after the build. The first video of each run "
  "will freeze the app until the cache is valid.")
