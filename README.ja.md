# CopyPath

macOS の Finder の右クリックメニューに、トップレベルで **「パスをコピー」** を追加する最小限の Finder Sync 拡張機能。

[English README](README.md)

## なぜ作るのか

macOS には Option + 右クリックでパスをコピーする隠し機能があるが、両手が必要で発見性も低い。

CopyPath は常時表示の **「パスをコピー」** メニュー項目をコンテキストメニューの上部に追加する。片手・ワンクリックでコピーできる。

## 機能

- **トップレベル**のメニュー項目（「クイックアクション」サブメニュー内ではない）
- ワンクリック・修飾キー不要
- 単一選択: そのファイルの POSIX パスをコピー
- 複数選択: 改行区切りで連結してコピー
- 何も選んでない状態で右クリック: 現在のフォルダのパスをコピー
- 英語・日本語対応

## インストール

```bash
./install.sh
```

ビルド → `~/Applications/CopyPath.app` にインストール → 拡張機能を登録・有効化 → Finder 再起動、まで一気にやる。終わったらファイルやフォルダを右クリック。

メニューに出ない場合は `~/Applications/CopyPath.app` を開いて、画面の指示に従ってシステム設定で有効化。

## 必要環境

- macOS 13.0 以降
- Xcode 16 以降
- [xcodegen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`)

## 既製品でいいのでは

商用代替品（PowerClick, Hookmark など）でも十分動く。CopyPath は以下を求める人向け：

- 30 行の Swift で全部読めるソース
- App Store や有料ライセンスに依存しない
- 独自フォーマット（URL エンコード、クォート、エスケープ等）を後から自分で足せる

## 仕組み

`FIFinderSync` サブクラスの `menu(for:)` で `NSMenuItem` を 1 つ返すだけ。クリック時に `selectedItemURLs()`（または空白右クリック時は `targetedURL()`）からパスを取得し、`NSPasteboard` に書き込む。

ホストアプリは macOS が拡張機能をパッケージングするために必要なだけで、起動時に説明ウィンドウを表示する以外の役割はない。

## ライセンス

MIT — [LICENSE](LICENSE) 参照。
