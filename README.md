# macOS AI 翻译与语法理解工具 · 交互设计稿 (Apple HIG)

本项目为一款面向日常开发和英文阅读的 macOS 系统级翻译与语法理解工具的完整交互原型套件。
遵循 Apple Human Interface Guidelines (HIG) 最新设计语言，并特别根据 Apple Developer 官方最新发布的 [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass) 规范，提供了完整的四款不同视觉风格交互原型。

## 🎨 四套设计风格原型

| 风格版本 | 核心视觉特征 | 交互原型文件 |
| :--- | :--- | :--- |
| **风格 1：原生 macOS Sonoma (经典 HIG)** | 经典 `NSVisualEffectView` 适度毛玻璃模糊、系统原生控件、高光内阴影边缘，完美融入 macOS 桌面 | [`index.html`](file:///Users/zhiyu/Desktop/coding/translator/index.html) |
| **风格 2：Apple 官方 Liquid Glass 规范 (新发布)** | **同心圆角几何 (Concentric Curvature)**、独立流体功能层、**流体按键 (.glass & .glassProminent)**、组合式工具栏与背景拓展折射层 | [`style_liquid_glass.html`](file:///Users/zhiyu/Desktop/coding/translator/style_liquid_glass.html) |
| **风格 3：Vision 空间流光磨砂 (Spatial Glass)** | 细腻喷砂噪点 (Frosted Grain)、多层晶体折射、彩虹高光折射顶沿、空间荧光语法光晕 | [`style_spatial_glass.html`](file:///Users/zhiyu/Desktop/coding/translator/style_spatial_glass.html) |
| **风格 4：柔光磨砂拟物微浮雕 (Tactile Neumorphic)** | 哑光喷砂表面、双向柔光软阴影 (Convex/Concave)、物理微动按键凹陷反馈、微下凹刻线语法槽 | [`style_neumorphic_tactile.html`](file:///Users/zhiyu/Desktop/coding/translator/style_neumorphic_tactile.html) |

## 快速预览

直接在浏览器中打开任一 HTML 文件即可体验：
- 默认主交互稿: `index.html`（已集成顶部风格无缝切换下拉菜单）
- **官方 Liquid Glass 原型: `style_liquid_glass.html`**
- Vision 空间磨砂玻璃稿: `style_spatial_glass.html`
- 柔光拟态微浮雕稿: `style_neumorphic_tactile.html`

本地启动 HTTP 服务（可选）：
```bash
python3 -m http.server 8000
# 访问 http://localhost:8000
```

## 覆盖的核心交互细节

1. **英文单词查询模式**（如 `architecture`, `persist`）：音标、原生 TTS 真实发音播放与动态声波、词性徽标、释义、按需展开搭配与例句。
2. **英文短句翻译与主干提取**（如 `The feature that we discussed yesterday has been implemented.`）：默认极简翻译，一键展开句子主干与成分标注。
3. **长难句从句结构可视化**（如 `Although the system was originally designed for small teams...`）：
   - 主语（蓝色实线）、谓语（橙色实线）、宾语（绿色实线）、补语（紫色实线）、状语（灰色虚线）
   - 定语从句、条件从句、让步从句（半透明圆角方框）
   - **Hover 250ms 防误触延迟浮现语法说明卡片**
   - **轻触成分固定说明卡片 (Click to Pin)**，支持选中文本复制，按 `Esc` 解除
4. **中译英地道表达建议**（如 `这个方案可以先作为一个兜底方案。`）：最佳自然表达、语气分析、更正式的替代表达、用词洞察。
5. **无选中文本兜底与手动输入**：友好空状态、直接输入翻译、500字长度限制提醒。
6. **macOS 辅助功能权限引导**：原生弹窗风格、三步系统设置图解。
7. **异常与降级**：网络超时重试、结构解析失败但保全翻译结果。
8. **macOS 偏好设置窗口 (⌘,)**：通用设置、语音发音（语速滑块与试听）、显示行为、LLM API 配置、本地 SQLite 缓存管理。
9. **macOS 菜单栏 (MenuBarExtra)**：常驻菜单栏图标与原生下拉菜单。
10. **外观模式切换**：macOS 深色外观 (Dark Mode) / 浅色外观 (Light Mode)。

## 设计规范文档索引

- 详细设计走查与 Apple HIG 映射文档: [`walkthrough.md`](file:///Users/zhiyu/.gemini/antigravity/brain/500e01be-b59a-42e1-a05f-6773d3e85c2a/walkthrough.md)
- 技术实现计划: [`implementation_plan.md`](file:///Users/zhiyu/.gemini/antigravity/brain/500e01be-b59a-42e1-a05f-6773d3e85c2a/implementation_plan.md)
