#ifndef RUNNER_SAVED_DOCUMENTS_H_
#define RUNNER_SAVED_DOCUMENTS_H_
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>
#include <memory>
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateSavedDocumentsChannel(flutter::BinaryMessenger* messenger, HWND window);
#endif
