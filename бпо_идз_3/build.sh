#!/bin/bash
# Обновлённый скрипт сборки OpenSSL 1.0.1f для Ubuntu 24.04

# Задаём нужную ветку/тег и URL репозитория
OPENSSL_VERSION="OpenSSL_1_0_1f"
GIT_REPO="https://github.com/openssl/openssl.git"

# Названия каталогов для исходников и сборки
SRC_DIR="SRC"
BUILD_DIR="BUILD"

# Удаляем старые исходники (если есть)
rm -rf "$SRC_DIR"

echo "Клонирование репозитория OpenSSL с тегом $OPENSSL_VERSION..."
git clone --branch "$OPENSSL_VERSION" --depth 1 "$GIT_REPO" "$SRC_DIR"
if [ $? -ne 0 ]; then
  echo "Ошибка: не удалось клонировать репозиторий."
  exit 1
fi

# Функция сборки библиотеки OpenSSL
build_lib() {
  rm -rf "$BUILD_DIR"
  cp -r "$SRC_DIR" "$BUILD_DIR"
  echo "Конфигурирование и сборка OpenSSL в каталоге $BUILD_DIR..."
  # Флаг no-asm отключает ассемблерные оптимизации, что часто требуется для OpenSSL 1.0.1f
  (cd "$BUILD_DIR" && CC="$CC $CFLAGS" ./config no-asm && make clean && make)
  if [ $? -ne 0 ]; then
    echo "Ошибка сборки OpenSSL."
    exit 1
  fi
}

build_lib

# Если в корне присутствует целевой файл, компилируем его с использованием собранных библиотек.
if [[ -f "target.cc" ]]; then
  echo "Компиляция target.cc..."
  # Задаём значения по умолчанию для переменных, если они не определены
  : ${CXX:=clang++}
  : ${CXXFLAGS:="-O2 -g"}
  : ${LIB_FUZZING_ENGINE:=""}
  : ${SCRIPT_DIR:=$(pwd)}
  : ${EXECUTABLE_NAME_BASE:="fuzzer_target"}
  
  $CXX $CXXFLAGS "$SCRIPT_DIR/target.cc" -DCERT_PATH="\"$SCRIPT_DIR/\"" \
    "$BUILD_DIR/libssl.a" "$BUILD_DIR/libcrypto.a" $LIB_FUZZING_ENGINE -I "$BUILD_DIR/include" -o "$EXECUTABLE_NAME_BASE"
  
  if [ $? -ne 0 ]; then
    echo "Ошибка компиляции target.cc."
    exit 1
  fi
fi

# Если существует папка runtime, копируем её в текущий каталог.
if [[ -d "$SCRIPT_DIR/runtime" ]]; then
  echo "Копирование папки runtime..."
  rm -rf runtime
  cp -r "$SCRIPT_DIR/runtime" .
fi

echo "Сборка завершена."
