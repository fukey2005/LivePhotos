enum ScreenState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(AppError)
}
