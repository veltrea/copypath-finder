# CopyPath

macOS の Finder の右クリック →「サービス」サブメニュー内に **「パスをコピー」** を追加する最小限のユーティリティ。

[English README](README.md)

## なぜ作るのか

macOS には Option + 右クリックでパスをコピーする隠し機能があるが、両手が必要で発見性も低い。

CopyPath はサービスメニュー経由で **「パスをコピー」** を提供する。ファイルを右クリック →「サービス」→「パスをコピー」でクリップボードに POSIX パスが入る。片手・ワンクリック。

## なぜトップレベルじゃなくサービスメニューなのか

最初の版は `FIFinderSync` 拡張で右クリックメニューのトップに項目を出していたが、これは用途違いだった。Apple の Developer Technical Support によると `FIFinderSync` は元々クラウド同期プロバイダ向けで、[任意のファイルにコンテキストメニュー項目を追加する用途は想定外](https://developer.apple.com/forums/thread/766680)。古い macOS では一部のフォルダでたまたま動いていたが、Sequoia ではユーザー領域のファイルでは反応しなくなる。同種の3rd party「パスをコピー」系アプリ（Hookmark、PathFinder 等）は全て Services 方式を採用している。

サービス API が現代の macOS で唯一サポートされた方法。トレードオフとして、メニュー項目は**「サービス」サブメニュー内**になりトップレベルには出せない（Apple が3rd party によるトップレベル右クリック項目の注入を許可していない）。

## 機能

- 任意のファイル・フォルダで動く（サービスメニュー経由）
- ワンクリック・修飾キー不要
- 単一選択: そのファイルの POSIX パスをコピー
- 複数選択: 改行区切りで連結してコピー
- 英語・日本語対応 (`Copy Path` / `パスをコピー`)
- 初回起動後はアプリが常駐し続けるので、毎回 Service 起動時にアプリが再起動されない（=セットアップウィンドウが再表示されない）

## インストール

1. [最新リリース](https://github.com/veltrea/copypath-finder/releases/latest)から `CopyPath-1.0.0.dmg` をダウンロード
2. DMG を開き、**CopyPath** を **Applications** フォルダのショートカットにドラッグ
3. `/Applications` から `CopyPath` を 1 回開く。macOS が「開発元が未確認」と警告するので（ad-hoc 署名で notarize されていないため）、**システム設定 → プライバシーとセキュリティ** で「**このまま開く**」をクリック → もう一度起動
4. セットアップウィンドウが表示される。閉じて構わない — CopyPath はバックグラウンドで動き続け、サービスは引き続き使える

その後は、**Finder でファイル右クリック → サービス → パスをコピー**。

キーボードショートカット割り当て: **システム設定 → キーボード → キーボードショートカット → サービス → ファイルとフォルダ → パスをコピー**。アプリのウィンドウのボタンからこのペインを直接開ける。

## ソースからビルド

Xcode 16+ と [xcodegen](https://github.com/yonsm/XcodeGen) (`brew install xcodegen`) が必要。

```bash
./install.sh
```

ビルド → `/Applications/CopyPath.app` にインストール → LaunchServices に登録 → `pbs` と Finder を再起動してサービスメニューに反映（Finder 再起動だけでは不十分、`pbs` がメニューをキャッシュしているため）→ bootstrap 完了のため 1 回起動、まで一気にやる。

開発反復用:

```bash
./scripts/dev-reinstall.sh --build
```

走ってる CopyPath プロセス（前ビルドの残骸含む）を全部強制停止、状態を全部クリーン（旧 FinderSync 拡張の登録残骸も含む）、再ビルド、`/Applications` に再インストール、`pbs` と Finder 再起動、アプリ再起動。built / installed のタイムスタンプと SHA を出力するので、ウィンドウタイトルバーの build スタンプと照合すれば今走ってるのが本当に最新ビルドか確認できる。

リリース用 DMG パッケージング:

```bash
./scripts/build-dmg.sh 1.0.0
```

`build/CopyPath-1.0.0.dmg` を出力。

## 必要環境

| | |
|---|---|
| エンドユーザー | macOS 13.0+ |
| ソースビルド | macOS 13.0+ · Xcode 16+ · [xcodegen](https://github.com/yonsm/XcodeGen) |

## 仕組み

- **Service 宣言**: `Info.plist` の `NSServices` エントリに `copyPath:` メッセージと `public.file-url` / `NSFilenamesPboardType` 送信タイプを宣言。ローカライズタイトルは `Base.lproj/ServicesMenu.strings` と `ja.lproj/ServicesMenu.strings`。
- **Service ハンドラ**: 起動時に自身をサービスプロバイダとして登録 (`NSApp.servicesProvider = self`)。ハンドラが受信ペーストボードから URL を読み、結合したパスを `NSPasteboard.general` に書き込む。
- **明示的 main()**: AppDelegate で `static func main()` を定義し、delegate を生成して `NSApp.run()` を呼ぶ。これがないと `@main` だけでは `NSApplicationMain` を呼ぶ main() が合成されるが、XIB がないため delegate がインスタンス化されない。結果 `applicationDidFinishLaunching` が一度も呼ばれず全てが死ぬ。
- **初回起動 bootstrap**: `lsregister -f -R -trusted <bundle>` でアプリを登録 →`NSUpdateDynamicServices()` でレジストリ更新 → `killall pbs && killall Finder` でメニュー再構築。`UserDefaults` フラグで 1 回だけ実行。
- **常駐**: `applicationShouldTerminateAfterLastWindowClosed` が `false` を返すので、セットアップウィンドウを閉じてもアプリは終了しない。次回以降 Service 呼び出しで macOS がアプリを再起動する必要がないので、ウィンドウが再表示されない。
- **Service 呼び出し時にウィンドウを抑制**: セットアップウィンドウは `DispatchWorkItem` で起動から ~400 ms 遅延して表示する。先に `copyPath(_:userData:error:)` が呼ばれたら（コールドスタートで Service 起動された場合がこれ）、その work item をキャンセル。結果ウィンドウは出ない。

## ライセンス

MIT — [LICENSE](LICENSE) 参照。
