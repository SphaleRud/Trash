#!/bin/bash
# Copyright 2016 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License");

# Подключаем вспомогательные скрипты (убедитесь, что они находятся в ../custom-build.sh и ../common.sh)
. "$(dirname "$0")/../custom-build.sh" "$1" "$2"
. "$(dirname "$0")/../common.sh"

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  # Отключаем ассемблерные оптимизации (флаг no-asm) для стабильной сборки на Ubuntu 24.04.
  (cd BUILD && CC="$CC $CFLAGS" ./config no-asm && make clean && make)
}

# Получаем исходный код OpenSSL из Git-репозитория, выбирая тег OpenSSL_1_0_1f
get_git_tag https://github.com/openssl/openssl.git OpenSSL_1_0_1f SRC

build_lib
build_fuzzer

if [[ "$FUZZING_ENGINE" == "hooks" ]]; then
  # Если используется режим "hooks", то подключаем AddressSanitizer для возможности перехвата вызовов (memcmp и т.п.)
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi

# Собираем целевую программу фаззера, ссылаясь на собранные библиотеки libssl.a и libcrypto.a,
# включая заголовки из каталога BUILD/include
$CXX $CXXFLAGS "$SCRIPT_DIR/target.cc" -DCERT_PATH="\"$SCRIPT_DIR/\"" \
  BUILD/libssl.a BUILD/libcrypto.a $LIB_FUZZING_ENGINE -I BUILD/include -o "$EXECUTABLE_NAME_BASE"

rm -rf runtime
cp -rf "$SCRIPT_DIR/runtime" .
