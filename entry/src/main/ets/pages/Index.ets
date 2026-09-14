import { AppShell } from './AppShell';

@Entry
@Component
struct Index {
  build() {
    Stack() {
      AppShell();
    }
    .width('100%')
    .height('100%')
  }
}
