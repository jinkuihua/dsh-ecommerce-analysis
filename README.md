# dsh-ecommerce-analysis

DSH（DeepSeek Harness）技能插件：注册 `ecommerce-data-analysis` 技能，分析电商后台订单与账单数据。

> A DSH skill plugin that registers the `ecommerce-data-analysis` skill for analyzing e-commerce order and bill data.

## 功能

- **退款类型分类**：基于订单明细 S 列备注区分退货退款 / 已发货仅退款，按「已发货退款成功」「已收货退款成功」口径合并统计。
- **退货率统计**：按订单追踪计算，各退款类型分列、按月汇总，不使用「当天比值」的旧口径。
- **拦截件与白嫖核算**：拦截件（未收货、全额退款）与被白嫖损耗（已收货、部分退款）单独核算，损耗按实际退款额计算，少退差额不计入损耗。
- **报表输出**：全新 xlsx 工作簿（表格 + 折线图 + 饼图），以农历春节为界限做跨年对比。
- **与 Markdown 报告同规格**：Excel 分节、口径、校验项与 Markdown 报告一一对应；已发货仅退款 / 退货退款 / 无退款订单各自单独成表并带订单编号；附 8 类 × 10 单抽样验证清单。
- **口径校验**：构成加总、金额对账、占比复核、周度加总均给出 PASS/FAIL。
- **附加能力**：支持从截图（工资单、账单图片）求和计算金额。

## 安装

通过 DSH 插件市场（dshmarket）搜索安装，或手动安装：

```bash
# npm 发布后
dsh plugin add dsh-ecommerce-analysis

# 直接从 GitHub 仓库安装
dsh plugin --profile web add github:OWNER/dsh-ecommerce-analysis

# 本地开发（链接工作目录）
dsh plugin --profile web add link:C:/path/to/ecommerce-analysis
```

安装后无需额外配置：插件在宿主 `skills` 服务的全局层注册技能，所有会话的技能目录都会出现 `ecommerce-data-analysis`。

## 使用

任意会话中直接描述任务即可，例如：

- 「用电商数据分析技能分析 3 月订单数据，输出退货率报告」
- 「帮我核对退款订单的类型分类，生成 Excel 明细表」
- 「这张工资单截图，帮我求和计算金额」

模型会自动加载技能；也可以在 GUI 技能列表里手动选择 `ecommerce-data-analysis`。

## 数据与隐私

插件只注册技能说明，不读取、不上传任何数据；分析过程完全在本地工作区完成（使用 office 系列技能读写 xlsx/csv）。

## 文件结构

```
├── index.js                  # 宿主插件：注册技能
├── cordis.patch.yml          # 插件加载补丁行
├── locale/{en,zh}.json       # 插件市场/设置中的标题与描述
├── icon.svg / icon.png       # 图标（svg 用于 DSH 显示，png 用于市场卡片）
├── market/                   # 提交到 awesome-dsh-plugin 的条目模板
├── push-to-github.cmd/.ps1   # 一键推送到 GitHub
├── publish-to-npm.cmd/.ps1   # 可选：发布到 npm
├── README.md
└── LICENSE
```

## 开发

```bash
node --check index.js
# 修改后在 DSH 中重新安装链接包：
#   plugin_manager -> remove_bundle -> install_bundle <本目录>
```

## 发布到插件市场

DSH 插件市场（[dshmarket](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin)）的插件列表来自 [awesome-dsh-plugin](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin) 策展仓库：

1. 把本仓库推到你的 GitHub（双击 `push-to-github.cmd`）；
2. 发布到 npm（可选但推荐，双击 `publish-to-npm.cmd`）或创建 GitHub Release tarball；
3. 在 awesome-dsh-plugin 仓库新增 `data/plugins/OWNER__REPO.yml`（内容见 `market/awesome-dsh-plugin-entry.yml`），提交 PR。

合并后站点与市场会自动重建，通常一天内显示。

## License

MIT
