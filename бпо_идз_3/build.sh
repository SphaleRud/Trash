#!/bin/bash
# Обновлённый скрипт сборки OpenSSL 1.0.1f для Ubuntu 24.04

# Подключаем вспомогательные скрипты (если они нужны, иначе данную часть можно удалить)
. "$(dirname "$0")/../custom-build.sh" "$1" "$2"
. "$(dirname "$0")/../common.sh"

build_lib() {
  rm -rf BUILD
  cp -rf SRC BUILD
  echo "Конфигурирование и сборка OpenSSL в каталоге BUILD..."
  # Флаги:
  #   no-asm    — отключает устаревшие ассемблерные оптимизации,
  #   no-shared — собирает статическую библиотеку,
  #   Выполнение `make depend` генерирует необходимые зависимости.
  (cd BUILD && \
     CC="$CC $CFLAGS" ./config no-asm no-shared && \
     make clean && \
     make depend && \
     make)
  if [ $? -ne 0 ]; then
    echo "Ошибка сборки OpenSSL."
    exit 1
  fi
}

# Получаем исходный код OpenSSL с нужным тегом
get_git_tag https://github.com/openssl/openssl.git OpenSSL_1_0_1f SRC
build_lib
build_fuzzer

if [[ "$FUZZING_ENGINE" == "hooks" ]]; then
  # Если используется режим "hooks", подключаем AddressSanitizer для перехвата вызовов, например, memcmp.
  LIB_FUZZING_ENGINE="$LIB_FUZZING_ENGINE -fsanitize=address"
fi

$CXX $CXXFLAGS "$SCRIPT_DIR/target.cc" -DCERT_PATH="\"$SCRIPT_DIR/\"" \
  BUILD/libssl.a BUILD/libcrypto.a $LIB_FUZZING_ENGINE -I BUILD/include -o "$EXECUTABLE_NAME_BASE"

rm -rf runtime
cp -rf "$SCRIPT_DIR/runtime" .
