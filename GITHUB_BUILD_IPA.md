# 用 GitHub 云端打包猫猫记账 IPA

本机没有 Mac/Xcode，所以用 GitHub Actions 的 macOS 云端环境生成 `.ipa`。

## 你要上传的文件

把当前项目根目录上传到 GitHub 仓库，至少要包含：

- `.github/workflows/build-catledger-ipa.yml`
- `ios/CatLedger/CatLedger.xcodeproj`
- `ios/CatLedger/CatLedger`

我已经把这些文件准备好了。

## 网页操作步骤

1. 打开 GitHub，创建一个新仓库。
2. 把项目压缩包上传到仓库，或用网页上传文件。
3. 进入仓库的 **Actions** 页面。
4. 左侧选择 **Build CatLedger unsigned IPA**。
5. 点击 **Run workflow**。
6. 等待构建完成。
7. 打开构建记录，在页面底部 **Artifacts** 下载：

```text
CatLedger-unsigned-ipa
```

8. 解压下载的 artifact，里面就是：

```text
CatLedger-unsigned.ipa
```

9. 把这个 `.ipa` 导入你的自签工具，重签后安装到 iPhone。

## 重要说明

- 这个工作流生成的是未签名 IPA，不能直接安装。
- 你需要用自己的自签工具重签。
- 默认 Bundle ID 是 `com.catledger.app`。
- 如果 GitHub Actions 提示 Actions 未启用，按页面提示启用即可。
