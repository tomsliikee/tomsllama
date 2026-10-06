/// How a reply should be produced. Lives in core because both the chat
/// feature and the timing estimates in core/services speak in these terms.
enum ChatExecutionMode {
  schnell,
  optimal,
  thinking,
}
