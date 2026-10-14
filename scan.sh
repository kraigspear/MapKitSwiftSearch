#!/bin/sh
# The default `swiftbuild` system's index makes Periphery report public API, such as
# `placemark(for:)`, as unused; the native build system's index does not.
periphery scan --format xcode -- --build-system native
