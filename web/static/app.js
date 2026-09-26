/* First-party UI. No analytics, external fonts, token storage, or payment-URL
   sharing. Account data is escaped before entering a template. */
(() => {
  "use strict";

  const main = document.getElementById("main");
  const dialog = document.getElementById("action-dialog");
  const state = {
    config: null,
    me: null,
    planId: "yearly",
    order: null,
    poll: null,
  };
  const path = window.location.pathname.replace(/\/+$/, "") || "/";
  const route = path === "/" ? "/" : `${path}/`;
  let toastTimer;
  let modalReturnFocus;
  let quoteSequence = 0;

  const escape = (value) =>
    String(value ?? "").replace(
      /[&<>"']/g,
      (char) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[char],
    );
  const money = (amount) =>
    new Intl.NumberFormat("zh-CN", {
      style: "currency",
      currency: "CNY",
      maximumFractionDigits: Number(amount) % 100 ? 2 : 0,
    }).format(Number(amount) / 100);
  const date = (seconds, time = true) =>
    seconds
      ? new Intl.DateTimeFormat("zh-CN", {
          timeZone: "Asia/Shanghai",
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
          ...(time
            ? {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
                hour12: false,
              }
            : {}),
        }).format(new Date(seconds * 1000))
      : "尚未开始";
  const statusNames = {
    eligible: "还未开始试用",
    trial: "试用中",
    paid: "已开通",
    expired: "已到期",
    pending: "待支付",
    closed: "已关闭",
    refunded: "已退款",
    requested: "已提交",
    reviewing: "审核中",
    approved: "已批准",
    processing: "退款处理中",
    succeeded: "已退款",
    failed: "处理失败",
    rejected: "未通过",
    open: "待处理",
    resolved: "已解决",
    waiting: "待补充信息",
  };
  const label = (status) => statusNames[status] || "处理中";
  const planById = (id) => state.config?.plans?.find((plan) => plan.id === id);
  const planName = (id) => planById(id)?.name || "个人版";
  const csrf = () =>
    document.cookie
      .split("; ")
      .find((item) => item.startsWith("csrftoken="))
      ?.split("=")
      .slice(1)
      .join("=") || "";
  const notice = (message, kind = "") =>
    `<div class="notice ${kind}" role="${kind === "error" ? "alert" : "status"}">${escape(message)}</div>`;

  function safeURL(value, { callback = false } = {}) {
    try {
      if (typeof value !== "string" || !value.trim()) return null;
      const url = new URL(value, location.origin);
      if (callback)
        return url.protocol === "appswitcher:" &&
          url.hostname === "auth" &&
          url.pathname === "/callback"
          ? url.href
          : null;
      if (
        url.protocol === "https:" ||
        (url.origin === location.origin &&
          ["http:", "https:"].includes(url.protocol))
      )
        return url.href;
    } catch (_) {
      /* Invalid URLs have no usable link. */
    }
    return null;
  }

  async function api(endpoint, { method = "GET", data, timeout = 20000 } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(`/api/v1${endpoint}`, {
        method,
        credentials: "same-origin",
        cache: "no-store",
        signal: controller.signal,
        headers: {
          Accept: "application/json",
          ...(method !== "GET"
            ? {
                "Content-Type": "application/json",
                "X-CSRFToken": decodeURIComponent(csrf()),
              }
            : {}),
        },
        ...(data !== undefined ? { body: JSON.stringify(data) } : {}),
      });
      let payload;
      try {
        payload = await response.json();
      } catch (_) {
        payload = null;
      }
      if (!response.ok) {
        const error = new Error(
          payload?.error?.message ||
            (response.status === 401
              ? "登录已过期，请重新登录。"
              : "服务暂时没有响应，请稍后重试。"),
        );
        if (response.status === 401 && state.me) {
          state.me = null;
          updateNav();
        }
        error.status = response.status;
        error.code = payload?.error?.code;
        throw error;
      }
      if (!payload) throw new Error("收到的响应不完整，请重试。");
      return payload;
    } catch (error) {
      if (error.name === "AbortError")
        throw new Error(
          method === "GET"
            ? "请求超时，请检查网络后重试。"
            : "请求超时，结果尚未确认。请先刷新状态，避免重复操作。",
        );
      if (error instanceof TypeError)
        throw new Error("暂时无法连接，请检查网络后重试。");
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }

  function flash(message, error = false) {
    const toast = document.getElementById("toast");
    clearTimeout(toastTimer);
    toast.textContent = message;
    toast.classList.toggle("error", error);
    toast.hidden = false;
    toastTimer = setTimeout(() => {
      toast.hidden = true;
    }, 5500);
  }

  function setMessage(container, message, kind = "error") {
    container.innerHTML = notice(message, kind);
  }

  function updateNav() {
    const account = document.getElementById("nav-account");
    account.href = state.me
      ? "/account/"
      : route === "/login/"
        ? location.pathname + location.search
        : loginURL();
    account.innerHTML = `${state.me ? "我的账号" : "登录账号"} <span aria-hidden="true">↗</span>`;
    document.querySelectorAll("[data-nav]").forEach((link) => {
      if (link.dataset.nav === route) link.setAttribute("aria-current", "page");
    });
  }

  function loginURL(next = route + location.search) {
    return `/login/?next=${encodeURIComponent(next)}`;
  }

  function nextURL() {
    const next = new URLSearchParams(location.search).get("next");
    if (
      !next ||
      !next.startsWith("/") ||
      next.startsWith("//") ||
      next.includes("\\")
    )
      return "/account/";
    const url = new URL(next, location.origin);
    return url.origin === location.origin && url.pathname !== "/login/"
      ? url.pathname + url.search
      : "/account/";
  }

  async function busy(button, action) {
    if (!button || button.disabled) return;
    const previous = button.textContent;
    button.disabled = true;
    button.setAttribute("aria-busy", "true");
    button.textContent = "请稍候…";
    try {
      return await action();
    } finally {
      if (button.isConnected) {
        button.disabled = button.dataset.locked === "true";
        button.removeAttribute("aria-busy");
        button.textContent = previous;
      }
    }
  }

  function openDialog(title, content) {
    clearTimeout(state.poll);
    if (!dialog.open) modalReturnFocus = document.activeElement;
    document.getElementById("dialog-content").innerHTML =
      `<div class="dialog-heading"><h2 id="dialog-title">${escape(title)}</h2><button class="dialog-close" type="button" data-close-dialog aria-label="关闭">×</button></div>${content}`;
    if (!dialog.open) dialog.showModal();
    dialog.querySelector("[data-close-dialog]").focus();
    dialog.querySelector("[data-close-dialog]").onclick = () => dialog.close();
  }

  dialog.addEventListener("close", () => {
    clearTimeout(state.poll);
    state.order = null;
    if (modalReturnFocus?.isConnected) modalReturnFocus.focus();
  });

  const title = (value) => {
    document.title =
      value === "AppSwitcher"
        ? "AppSwitcher · 把切换交给键盘"
        : `${value} · AppSwitcher`;
  };

  function keyboardDemo() {
    const keys = [
      ["Q", "浏览器", "◎"],
      ["W", "邮件", "@"],
      ["E", "访达", "⌘"],
      ["R", "备忘录", "N"],
      ["T", "终端", ">_"],
      ["A", "日历", "25"],
      ["S", "音乐", "♫"],
      ["D", "文稿", "D"],
      ["F", "设计", "F"],
    ];
    const key = ([letter, name, icon]) =>
      `<button type="button" class="demo-key ${letter === "R" ? "is-active" : ""}" data-demo-key="${letter}" data-demo-name="${name}" aria-label="演示：选择${name}，键位 ${letter}" aria-pressed="${letter === "R"}"><span class="app-glyph" aria-hidden="true">${escape(icon)}</span><span class="demo-app-name">${name}</span><kbd>${letter}</kbd></button>`;
    return `<div class="demo-shell" aria-label="可互动的键盘切换演示"><div class="demo-top"><span>应用切换</span><span>示例快捷键 <kbd>⌘ E</kbd></span></div><div class="keyboard-row">${keys.slice(0, 5).map(key).join("")}</div><div class="keyboard-row">${keys.slice(5).map(key).join("")}</div><div class="demo-bottom"><span>互动演示 · 点击键帽试一试</span><span id="demo-status" role="status" aria-live="polite">已选择 备忘录</span></div></div>`;
  }

  function home() {
    title("AppSwitcher");
    main.innerHTML = `<div class="page-width"><section class="hero"><div class="hero-copy"><p class="eyebrow">为 Mac 上的专注时刻</p><h1>把切换交给键盘，<br><span>把注意力留给你。</span></h1><p>唤出面板，按下字母。<br>在应用之间，顺手往来。</p><div class="button-row"><a class="btn btn-primary" href="/download/">获取 Mac 版 <span aria-hidden="true">↗</span></a><a class="btn btn-quiet" href="#how-it-works">看看它怎么用 <span aria-hidden="true">↓</span></a></div></div>${keyboardDemo()}</section><div class="intro-strip"><div><strong>14 天</strong><p>全功能试用，无需绑卡</p></div><div><strong>不限设备</strong><p>同一账号，衔接每台 Mac</p></div><div><strong>主动续费</strong><p>按月、季、年，不自动扣款</p></div></div><section class="feature-section" id="how-it-works"><h2>切换更直接，工作不断线。</h2><p>把常用应用放到看得清、按得到的键位上。<br>少一次寻找，多一点连贯。</p><div class="features-layout"><article class="feature-panel primary"><div><h3>从你顺手的快捷键开始</h3><p>自定义唤出组合键，打开清晰的大图标面板，再按目标键位完成切换。</p></div><div><div class="shortcut-large" aria-label="示例：Command 加 E，接着按 R"><kbd>⌘</kbd><kbd>E</kbd><span>→</span><kbd>R</kbd></div><p class="small">示例键位。实际分配会随正在运行的应用变化。</p></div></article><article class="feature-panel"><h3>应用与窗口，各得其所</h3><p>默认按应用切换。能可靠识别的窗口可以展开选择，其余保留清晰的应用入口。</p></article><article class="feature-panel"><h3>你的工作内容，留在本机</h3><p>切换不上传窗口标题、屏幕内容或按键。联网用于账号、授权和你主动提交的反馈。</p></article></div></section><section class="section-cta"><div><h2>先用起来，再决定。</h2><p>安装后登录，在 App 内主动开始 14 天试用。</p></div><a class="btn btn-secondary" href="/pricing/">了解购买方案 <span aria-hidden="true">↗</span></a></section></div>`;
    main.querySelectorAll("[data-demo-key]").forEach((button) =>
      button.addEventListener("click", () => {
        main.querySelectorAll("[data-demo-key]").forEach((key) => {
          key.classList.toggle("is-active", key === button);
          key.setAttribute("aria-pressed", String(key === button));
        });
        document.getElementById("demo-status").textContent =
          `已选择 ${button.dataset.demoName}`;
      }),
    );
  }

  function faq(items) {
    return items
      .map(
        ([question, answer]) =>
          `<details><summary>${escape(question)}</summary><p>${escape(answer)}</p></details>`,
      )
      .join("");
  }

  function pricing() {
    title("价格");
    const plans = state.config.plans;
    if (!planById(state.planId)) state.planId = plans[0]?.id;
    main.innerHTML = `<div class="page-width"><header class="page-heading"><h1>同样完整的体验，<br>选择适合你的时间。</h1><p>所有方案功能相同，不限设备。不自动续费，提前购买保留剩余时间。</p></header><div class="plan-layout"><div class="plan-options" role="group" aria-label="选择购买期限">${plans.map((plan) => `<button type="button" class="plan-option ${plan.id === state.planId ? "is-selected" : ""}" data-plan="${escape(plan.id)}" aria-pressed="${plan.id === state.planId}"><div><h3>${escape(plan.name)}${plan.id === "yearly" ? '<span class="plan-tag">长期使用更合适</span>' : ""}</h3><p>${plan.months} 个日历月 · 完整个人版</p></div><div class="plan-price">${money(plan.amount)}<span> / ${plan.months === 1 ? "月" : plan.months === 3 ? "季" : "年"}</span></div></button>`).join("")}</div><section class="checkout-panel"><h2>把每一次切换，用顺手。</h2><ul class="benefits"><li>应用切换与支持的窗口切换</li><li>自定义唤出快捷键与清晰大图标</li><li>不限设备，账号权益同步</li><li>有效期内最长 7 天离线使用</li></ul><div id="checkout-content"></div></section></div><section class="faq-section"><h2>购买前，你可能想了解</h2>${faq(
      [
        [
          "提前续费会损失剩余时间吗？",
          "不会。新购买的 1、3 或 12 个月接在现有有效期之后。试用期内购买也保留剩余试用。到期后重新购买，则从本次成功开通时重新起算，不补收停用时间。",
        ],
        [
          "每月会自动扣款吗？",
          "不会。每次付款都由你主动发起，没有自动代扣。到期后可以随时选择月、季或年续费。",
        ],
        [
          "可以先试用吗？",
          "可以。每个账号有一轮连续 14 天全功能试用，不需要绑定付款方式。下载、注册不会开始计时，请在 App 内主动点击开始试用。尚未试用直接购买，则从开通时开始付费期限，不再追加免费试用。",
        ],
        [
          "一个账号可以用几台电脑？",
          "不限制设备数量或同时在线台数。目前提供 macOS 15 及以上 Apple Silicon 版本；Windows 尚未提供。设备管理只用于账号安全和主动退出。",
        ],
        [
          "不合适，可以退款吗？",
          "首次购买成功后 7 天内可申请全额退款；如果我们延迟开通，则至少保留开通后 7 天。尚未起算的续费也可申请整单退款。已经起算的非首次续费通常不按剩余天数退款；重复扣款、未开通和确认故障单独处理。详见服务与退款条款。",
        ],
      ],
    )}</section></div>`;
    document.querySelectorAll("[data-plan]").forEach(
      (button) =>
        (button.onclick = () => {
          state.planId = button.dataset.plan;
          document.querySelectorAll("[data-plan]").forEach((item) => {
            item.classList.toggle("is-selected", item === button);
            item.setAttribute("aria-pressed", String(item === button));
          });
          checkout();
        }),
    );
    checkout();
  }

  function checkout() {
    const container = document.getElementById("checkout-content");
    if (!state.config.termsVersion) {
      container.innerHTML = notice(
        "购买条款暂时无法读取，请刷新页面后重试。",
        "error",
      );
      return;
    }
    if (!state.me) {
      container.innerHTML = `<p class="small">购买将绑定你的账号，换电脑也能继续使用。</p><a class="btn btn-primary full-width" href="${loginURL("/pricing/")}">登录后购买</a>`;
      return;
    }
    const channels = [
      ["wechat", "微信支付"],
      ["alipay", "支付宝"],
      ["simulated", "演示支付（不产生真实扣款）"],
    ].filter(
      ([id]) =>
        state.config.payments[id] &&
        (id !== "simulated" || state.config.environment === "development"),
    );
    const plan = planById(state.planId);
    container.innerHTML = `<p class="small account-email">购买账号：${escape(state.me.account.email)}</p><div id="quote-preview" class="expiry-preview" role="status">正在计算购买后的期限…</div>${state.me.entitlement.status === "eligible" ? notice("你还未开始免费试用，可以先在 App 体验。直接购买将立即开通付费期限，不再追加一轮免费试用。") : ""}${channels.length ? `<form id="checkout-form"><div class="field"><label for="payment-channel">付款方式</label><select id="payment-channel" name="channel">${channels.map(([id, text]) => `<option value="${id}">${text}</option>`).join("")}</select></div><label class="consent"><input type="checkbox" name="consent" required><span>我已阅读 <a class="text-link" href="/terms/" target="_blank" rel="noopener">服务与退款条款</a>。本次为主动购买，不自动扣款。</span></label><button class="btn btn-primary full-width" type="submit">购买${escape(plan.name)} · ${money(plan.amount)}</button><div id="checkout-message"></div></form>` : notice("在线购买尚未开放。你可以先了解方案，已购用户仍可在账号中心查看权益。")}`;
    loadQuote(state.planId);
    const form = document.getElementById("checkout-form");
    if (!form) return;
    const idempotencyKey = crypto.randomUUID();
    form.onsubmit = (event) => {
      event.preventDefault();
      busy(form.querySelector("button[type=submit]"), async () => {
        try {
          const result = await api("/orders", {
            method: "POST",
            data: {
              planId: plan.id,
              channel: new FormData(form).get("channel"),
              idempotencyKey,
              acceptedTerms: form.elements.consent.checked,
              termsVersion: state.config.termsVersion,
              expectedAmount: plan.amount,
              expectedCurrency: plan.currency,
            },
          });
          paymentDialog(result);
        } catch (error) {
          if (["price_changed", "terms_updated"].includes(error.code)) {
            showCheckoutUpdate(
              error.message,
              document.getElementById("checkout-message"),
            );
            return;
          }
          setMessage(
            document.getElementById("checkout-message"),
            error.message,
          );
        }
      });
    };
  }

  function showCheckoutUpdate(message, target) {
    target.innerHTML = `${notice(message, "error")}<button type="button" class="btn btn-secondary btn-small" id="refresh-purchase-terms">查看最新方案与条款</button>`;
    const purchase = document.querySelector(
      "#checkout-form button[type=submit]",
    );
    if (purchase) {
      purchase.disabled = true;
      purchase.dataset.locked = "true";
    }
    document.getElementById("refresh-purchase-terms").onclick = (event) =>
      busy(event.currentTarget, async () => {
        try {
          state.config = await api("/config");
          pricing();
          const message = document.getElementById("checkout-message");
          if (message)
            setMessage(
              message,
              "方案已刷新。请核对金额、期限与条款，重新同意后再购买。",
              "",
            );
        } catch (error) {
          flash(error.message, true);
        }
      });
  }

  async function loadQuote(planId) {
    const seq = ++quoteSequence;
    const target = document.getElementById("quote-preview");
    const purchase = document.querySelector(
      "#checkout-form button[type=submit]",
    );
    if (purchase) purchase.disabled = true;
    try {
      const result = await api(
        `/orders/quote?planId=${encodeURIComponent(planId)}`,
      );
      if (seq !== quoteSequence || !target.isConnected) return;
      const plan = planById(planId);
      if (result.amount !== plan.amount || result.currency !== plan.currency) {
        showCheckoutUpdate("方案价格已更新，请先查看最新价格再购买。", target);
        return;
      }
      target.innerHTML = `预计购买期限（北京时间）<strong>${date(result.startsAt)} 至 ${date(result.endsAt)}</strong><span>支付确认后，以订单实际发放时间为准。</span>`;
      if (purchase) purchase.disabled = false;
    } catch (error) {
      if (seq !== quoteSequence || !target.isConnected) return;
      target.innerHTML = `${notice(`暂时无法计算购买期限。${error.message}`, "error")}<button type="button" class="btn btn-secondary btn-small" id="retry-quote">重新计算</button>`;
      document.getElementById("retry-quote").onclick = () => loadQuote(planId);
    }
  }

  function drawQR(value) {
    const holder = document.getElementById("payment-qr");
    try {
      const qr = window.qrcode(0, "M");
      qr.addData(value);
      qr.make();
      const count = qr.getModuleCount();
      const scale = 5,
        quiet = 4;
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = (count + quiet * 2) * scale;
      canvas.setAttribute("role", "img");
      canvas.setAttribute("aria-label", "请用微信扫描付款二维码");
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#000000";
      for (let row = 0; row < count; row++)
        for (let col = 0; col < count; col++)
          if (qr.isDark(row, col))
            ctx.fillRect(
              (col + quiet) * scale,
              (row + quiet) * scale,
              scale,
              scale,
            );
      holder.replaceChildren(canvas);
    } catch (_) {
      holder.innerHTML = notice(
        "二维码暂时无法显示。请关闭后从订单重新打开付款。",
        "error",
      );
    }
  }

  function paymentDialog(result) {
    const { order, payment } = result;
    state.order = order;
    const complete = ["paid", "refunded", "closed"].includes(order.status);
    const redirect = payment?.kind === "redirect" ? safeURL(payment.url) : null;
    openDialog(
      complete ? label(order.status) : "完成购买",
      `<div class="payment-summary"><div>${escape(planName(order.planId))}<p class="small">${escape(state.me.account.email)}</p></div><strong>${money(order.amount)}</strong></div><div id="payment-state">${order.status === "paid" ? notice(`已开通，有效至 ${date(order.endsAt)}（北京时间）。回到 App 同步已购权益即可。`, "success") : order.status === "refunded" ? notice("此订单已退款。其他订单的有效期请在账号中心查看。") : order.status === "closed" ? notice("此订单已关闭，不能继续付款。") : payment?.kind === "qr" && payment.url ? `<div id="payment-qr" class="payment-qr"></div><p class="payment-instruction">请使用微信扫描二维码付款</p>` : redirect ? `<a class="btn btn-primary full-width" href="${escape(redirect)}" target="_blank" rel="noopener noreferrer">前往支付宝付款 <span aria-hidden="true">↗</span></a>` : payment?.kind === "simulated" && state.config.environment === "development" ? `${notice("演示环境：以下操作仅用于验证流程，不产生真实付款。")}<button id="simulate-payment" class="btn btn-secondary full-width">模拟付款成功</button>` : notice("付款入口暂时不可用。请稍后从订单页面重试。", "error")}</div><p class="order-id">订单编号：${escape(order.id)}</p>${!complete ? '<p class="waiting-copy">付过款却未开通？先刷新付款状态，无需再次付款。关闭本页后也可以在订单中继续查看。</p><button id="sync-payment" class="btn btn-secondary full-width">我已付款，刷新状态</button>' : '<a class="btn btn-primary full-width" href="/account/">查看我的授权</a>'}<div id="payment-message"></div><a class="btn btn-quiet full-width" href="/orders/">查看全部订单</a>`,
    );
    state.order = order;
    if (payment?.kind === "qr" && payment.url && !complete) drawQR(payment.url);
    const sync = document.getElementById("sync-payment");
    if (sync)
      sync.onclick = () =>
        busy(sync, async () => {
          try {
            const updated = await api(
              `/orders/${encodeURIComponent(order.id)}/sync`,
              { method: "POST" },
            );
            if (updated.order.status !== "pending") {
              state.me = await api("/me");
              paymentDialog(updated);
            } else
              setMessage(
                document.getElementById("payment-message"),
                "尚未确认付款。若已付款，请稍候再查，不要重复支付。",
                "",
              );
          } catch (error) {
            setMessage(
              document.getElementById("payment-message"),
              error.message,
            );
          }
        });
    const simulate = document.getElementById("simulate-payment");
    if (simulate)
      simulate.onclick = () =>
        busy(simulate, async () => {
          try {
            const updated = await api(
              `/orders/${encodeURIComponent(order.id)}/simulate`,
              { method: "POST" },
            );
            state.me = await api("/me");
            paymentDialog(updated);
          } catch (error) {
            setMessage(
              document.getElementById("payment-message"),
              error.message,
            );
          }
        });
    if (!complete) pollOrder(order.id, 0);
  }

  function pollOrder(id, attempt) {
    clearTimeout(state.poll);
    if (attempt >= 30) return;
    state.poll = setTimeout(
      async () => {
        if (!dialog.open || state.order?.id !== id) return;
        if (document.hidden) {
          pollOrder(id, attempt + 1);
          return;
        }
        try {
          const updated = await api(`/orders/${encodeURIComponent(id)}`);
          if (!dialog.open || state.order?.id !== id) return;
          if (updated.order.status !== "pending") {
            state.me = await api("/me");
            paymentDialog(updated);
            return;
          }
        } catch (_) {
          /* Manual sync remains available; do not overwrite payment UI. */
        }
        pollOrder(id, attempt + 1);
      },
      attempt < 6 ? 4000 : 10000,
    );
  }

  function login() {
    title("登录");
    if (!state.config.termsVersion || !state.config.privacyVersion) {
      main.innerHTML =
        '<div class="standalone-error"><h1>服务说明暂时无法读取。</h1><p>请刷新页面后再登录，你的账号与权益不会受到影响。</p><a class="btn btn-secondary" href="/login/">重新加载</a></div>';
      return;
    }
    if (state.me) {
      location.replace(nextURL());
      return;
    }
    main.innerHTML = `<div class="page-width auth-layout"><div class="auth-description"><div class="auth-key" aria-hidden="true">⌘</div><h1>每台 Mac，<br>都是熟悉的你。</h1><p>一个账号管理授权、订单与反馈。<br>无需记住新密码，用邮箱验证码登录。</p></div><section class="auth-card"><h2>登录或创建账号</h2><p>首次验证邮箱后，将为你创建账号。</p><form id="login-form"><div class="field"><label for="email">邮箱地址</label><input id="email" name="email" type="email" autocomplete="email" placeholder="you@example.com" required maxlength="254"></div><label class="consent"><input name="consent" type="checkbox" required><span>我已阅读并同意 <a class="text-link" href="/terms/" target="_blank" rel="noopener">服务条款</a> 与 <a class="text-link" href="/privacy/" target="_blank" rel="noopener">隐私说明</a>。</span></label><button type="submit" class="btn btn-primary full-width">获取验证码</button><div id="login-message"></div></form><div id="verify-step" hidden></div></section></div>`;
    const form = document.getElementById("login-form");
    form.onsubmit = (event) => {
      event.preventDefault();
      busy(form.querySelector("button"), async () => {
        const email = new FormData(form).get("email").trim();
        try {
          await api("/auth/request-code", { method: "POST", data: { email } });
          form.hidden = true;
          const step = document.getElementById("verify-step");
          step.hidden = false;
          step.innerHTML = `<p class="small">如果该邮箱可接收邮件，验证码已发送至<br><strong class="account-email">${escape(email)}</strong></p><form id="verify-form"><div class="field"><div class="inline-label"><label for="login-code">邮件验证码</label><button type="button" id="change-email">修改邮箱</button></div><input id="login-code" name="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{6}" maxlength="6" minlength="6" placeholder="6 位数字" required></div><button class="btn btn-primary full-width" type="submit">验证并登录</button><div id="verify-message"></div></form><button class="btn btn-quiet" id="resend-code" disabled>60 秒后重新发送</button><p class="field-hint">未收到？请检查垃圾邮件。验证码只用于登录，请勿转发。</p>`;
          document.getElementById("login-code").focus();
          const resend = document.getElementById("resend-code");
          let remaining = 60;
          let interval;
          const countdown = () => {
            clearInterval(interval);
            remaining = 60;
            resend.disabled = true;
            resend.textContent = "60 秒后重新发送";
            interval = setInterval(() => {
              remaining--;
              if (!resend.isConnected || remaining <= 0) {
                clearInterval(interval);
                resend.disabled = false;
                resend.textContent = "重新发送验证码";
              } else resend.textContent = `${remaining} 秒后重新发送`;
            }, 1000);
          };
          countdown();
          document.getElementById("change-email").onclick = () => {
            clearInterval(interval);
            step.hidden = true;
            form.hidden = false;
            document.getElementById("email").focus();
          };
          resend.onclick = () =>
            busy(resend, async () => {
              try {
                await api("/auth/request-code", {
                  method: "POST",
                  data: { email },
                });
                flash("验证码已重新发送，请检查邮箱。");
              } catch (error) {
                setMessage(
                  document.getElementById("verify-message"),
                  error.message,
                );
              }
            }).then(() => countdown());
          const verifyForm = document.getElementById("verify-form");
          verifyForm.onsubmit = (event) => {
            event.preventDefault();
            busy(verifyForm.querySelector("button[type=submit]"), async () => {
              try {
                state.me = await api("/auth/verify-code", {
                  method: "POST",
                  data: {
                    email,
                    code: new FormData(verifyForm).get("code").trim(),
                    acceptedTerms: verifyForm.elements.renewedConsent
                      ? verifyForm.elements.renewedConsent.checked
                      : form.elements.consent.checked,
                    termsVersion: state.config.termsVersion,
                    privacyVersion: state.config.privacyVersion,
                  },
                });
                clearInterval(interval);
                location.replace(nextURL());
              } catch (error) {
                if (
                  error.code === "terms_updated" ||
                  error.code === "agreement_required"
                ) {
                  try {
                    const config = await api("/config");
                    if (!config.termsVersion || !config.privacyVersion)
                      throw new Error("最新条款暂时无法读取，请稍后重试。");
                    state.config = config;
                    let updated = document.getElementById("renewed-consent");
                    if (!updated) {
                      updated = document.createElement("div");
                      updated.id = "renewed-consent";
                      verifyForm.prepend(updated);
                    }
                    updated.innerHTML = `${notice("服务说明已更新，请重新阅读并同意后继续验证。")}<label class="consent"><input type="checkbox" name="renewedConsent" required><span>我已阅读并同意最新的 <a class="text-link" href="/terms/" target="_blank" rel="noopener">服务条款 ${escape(config.termsVersion)}</a> 与 <a class="text-link" href="/privacy/" target="_blank" rel="noopener">隐私说明 ${escape(config.privacyVersion)}</a>。</span></label>`;
                    document.getElementById("verify-message").replaceChildren();
                  } catch (updateError) {
                    setMessage(
                      document.getElementById("verify-message"),
                      updateError.message,
                    );
                  }
                  return;
                }
                setMessage(
                  document.getElementById("verify-message"),
                  error.message,
                );
              }
            });
          };
        } catch (error) {
          setMessage(document.getElementById("login-message"), error.message);
        }
      });
    };
  }

  function accountShell(content, active = route) {
    return `<div class="page-width workspace"><nav class="account-nav" aria-label="账号导航">${[
      ["/account/", "我的授权"],
      ["/orders/", "订单与退款"],
      ["/download/", "下载与更新"],
      ["/support/", "帮助与反馈"],
    ]
      .map(
        ([url, text]) =>
          `<a href="${url}" ${active === url ? 'aria-current="page"' : ""}>${text}</a>`,
      )
      .join(
        "",
      )}<div class="nav-divider"></div><button type="button" id="logout">退出网页登录</button></nav><div>${content}</div></div>`;
  }

  function bindLogout() {
    const button = document.getElementById("logout");
    if (button)
      button.onclick = () =>
        busy(button, async () => {
          try {
            await api("/auth/logout", { method: "POST" });
            location.assign("/");
          } catch (error) {
            flash(error.message, true);
          }
        });
  }

  async function account() {
    title("我的授权");
    const entitlement = state.me.entitlement;
    const eligible = entitlement.status === "eligible";
    const trialQueued = entitlement.status === "trial" && entitlement.paidUntil;
    main.innerHTML = accountShell(
      `<header class="workspace-heading"><div><h1>我的授权</h1><p class="account-email">${escape(state.me.account.email)}</p></div><button id="refresh-account" class="btn btn-secondary btn-small">同步权益</button></header><section class="license-panel"><div><div class="status-label">${label(entitlement.status)}</div><h2>${eligible ? "准备好，让切换更顺手。" : entitlement.status === "expired" ? "继续你熟悉的节奏。" : trialQueued ? "试用后，付费期限已安排。" : "每台 Mac，都能继续。"}</h2><p class="license-expiry">${eligible ? "14 天全功能试用，等你主动开始。" : `有效至 ${date(entitlement.validUntil)} · 北京时间`}</p>${trialQueued ? `<p class="small">试用结束：${date(entitlement.trialEndsAt)}，之后接续已购期限。</p>` : ""}</div><div class="button-row"><a class="btn btn-primary" href="${eligible ? "/download/" : "/pricing/"}">${eligible ? "下载并在 App 开始试用" : entitlement.status === "expired" ? "续费恢复使用" : "购买更多时间"}</a></div></section><div class="account-note"><span aria-hidden="true">⌘</span><p>不限设备，不自动扣款。${eligible ? "下载和注册不会开始计时，请在 App 内登录并点击开始试用。" : "网页购买后，在 App 内点击“同步已购权益”即可刷新。你的快捷键和偏好会保留。"}</p></div><div class="section-title"><h2>已登录的电脑</h2><p>用于账号安全，不设设备额度</p></div><div id="sessions" aria-live="polite"><div class="skeleton-line"></div><div class="skeleton-line"></div><span class="sr-only">正在加载登录会话</span></div>`,
    );
    bindLogout();
    document.getElementById("refresh-account").onclick = (event) =>
      busy(event.currentTarget, async () => {
        try {
          state.me = await api("/me");
          await account();
          flash("已同步最新权益。");
        } catch (error) {
          flash(error.message, true);
        }
      });
    await loadSessions();
  }

  async function loadSessions() {
    const container = document.getElementById("sessions");
    try {
      const result = await api("/sessions");
      container.innerHTML = result.sessions.length
        ? `<div class="sessions">${result.sessions.map((session) => `<article class="session-row"><div><h3>${escape(session.label || "Mac 电脑")} ${session.current ? '<span class="tag">当前会话</span>' : ""}</h3><p>最近连接 ${date(session.lastSeenAt)} · 北京时间</p></div><button class="btn btn-secondary btn-small" data-revoke="${escape(session.id)}" data-session-name="${escape(session.label || "此电脑")}">退出</button></article>`).join("")}</div>`
        : '<div class="empty-state"><h3>还没有登录的电脑</h3><p>在 App 中选择登录，浏览器确认后，电脑会显示在这里。</p><a class="btn btn-secondary btn-small" href="/download/">获取 Mac 版</a></div>';
      container.querySelectorAll("[data-revoke]").forEach(
        (button) =>
          (button.onclick = () => {
            openDialog(
              "退出此电脑？",
              `<p class="dialog-copy">${escape(button.dataset.sessionName)} 将需要重新登录。其他电脑和本地设置不会被删除。完全离线的设备将在本地授权到期后停止使用。</p><button id="confirm-revoke" class="btn btn-danger full-width">退出这台电脑</button><div id="revoke-message"></div>`,
            );
            document.getElementById("confirm-revoke").onclick = (event) =>
              busy(event.currentTarget, async () => {
                try {
                  await api(
                    `/sessions/${encodeURIComponent(button.dataset.revoke)}/revoke`,
                    { method: "POST" },
                  );
                  dialog.close();
                  await loadSessions();
                  flash("已撤销该电脑的登录会话。");
                } catch (error) {
                  setMessage(
                    document.getElementById("revoke-message"),
                    error.message,
                  );
                }
              });
          }),
      );
    } catch (error) {
      container.innerHTML = `${notice(error.message, "error")}<button class="btn btn-secondary btn-small" id="retry-sessions">重新加载</button>`;
      document.getElementById("retry-sessions").onclick = loadSessions;
    }
  }

  async function orders() {
    title("订单与退款");
    main.innerHTML = accountShell(
      '<header class="workspace-heading"><div><h1>订单与退款</h1><p>每笔购买、权益期限与处理进度，都在这里。</p></div><a class="btn btn-secondary btn-small" href="/pricing/">购买</a></header><div id="order-list" aria-live="polite"><div class="page-loader"><span class="spinner" aria-hidden="true"></span>正在读取订单…</div></div>',
    );
    bindLogout();
    await loadOrders();
  }

  async function loadOrders() {
    const container = document.getElementById("order-list");
    try {
      const result = await api("/orders");
      container.innerHTML = result.orders.length
        ? `<div class="order-list">${result.orders.map((order) => `<article class="order-card"><div class="order-top"><div><h2>${escape(planName(order.planId))}</h2><p>${date(order.createdAt)} · 北京时间</p></div><div><div class="order-amount">${money(order.amount)}</div><span class="tag status-${escape(order.status)}">${label(order.status)}</span></div></div><div class="order-details"><div><span>支付方式</span>${{ wechat: "微信支付", alipay: "支付宝", simulated: "演示支付" }[order.channel] || "支付渠道"}</div>${order.startsAt ? `<div><span>生效时间（北京时间）</span>${date(order.startsAt)}</div><div><span>到期时间（北京时间）</span>${date(order.endsAt)}</div>` : "<div><span>授权期限</span>付款确认后发放</div>"}${order.refundStatus ? `<div><span>退款进度</span>${label(order.refundStatus)}</div>` : ""}</div><div class="button-row">${order.status === "pending" ? `<button class="btn btn-primary btn-small" data-pay-order="${escape(order.id)}">继续付款 / 查单</button>` : ""}${order.status === "paid" && !order.refundStatus ? `<button class="btn btn-secondary btn-small" data-refund-order="${escape(order.id)}">申请退款</button>` : ""}<a class="btn btn-quiet btn-small" href="/support/?order=${encodeURIComponent(order.id)}">联系支持</a></div><p class="order-id">订单编号：${escape(order.id)}</p></article>`).join("")}</div>`
        : '<div class="empty-state"><h2>你的第一笔订单，还没开始。</h2><p>购买后，付款状态和使用期限会保存在这里。已经付款却没有记录？请确认登录的是购买时使用的邮箱。</p><div class="button-row"><a class="btn btn-primary" href="/pricing/">查看购买方案</a><a class="btn btn-secondary" href="/support/">联系支持</a></div></div>';
      container.querySelectorAll("[data-pay-order]").forEach(
        (button) =>
          (button.onclick = () =>
            busy(button, async () => {
              try {
                paymentDialog(
                  await api(
                    `/orders/${encodeURIComponent(button.dataset.payOrder)}`,
                  ),
                );
              } catch (error) {
                flash(error.message, true);
              }
            })),
      );
      container
        .querySelectorAll("[data-refund-order]")
        .forEach(
          (button) =>
            (button.onclick = () => refundDialog(button.dataset.refundOrder)),
        );
    } catch (error) {
      container.innerHTML = `${notice(error.message, "error")}<button class="btn btn-secondary" id="retry-orders">重新加载订单</button>`;
      document.getElementById("retry-orders").onclick = loadOrders;
    }
  }

  function refundDialog(id) {
    openDialog(
      "申请退款",
      `<p class="dialog-copy">申请不会立即取消其他订单的授权。我们会核查订单与退款规则，并在此订单中更新进度。</p><form id="refund-form"><div class="field"><label for="refund-reason">退款原因</label><textarea id="refund-reason" name="reason" placeholder="例如：无法正常切换某个应用。请描述使用场景，不要填写密码或付款敏感信息。" required minlength="5" maxlength="2000"></textarea></div><p class="field-hint">首次购买 7 天内、尚未起算的续费可申请整单退款。重复扣款、未开通或产品故障会单独核查。</p><button class="btn btn-primary full-width" type="submit">提交退款申请</button><div id="refund-message"></div></form>`,
    );
    const form = document.getElementById("refund-form");
    form.onsubmit = (event) => {
      event.preventDefault();
      busy(form.querySelector("button"), async () => {
        try {
          await api(`/orders/${encodeURIComponent(id)}/refund`, {
            method: "POST",
            data: { reason: new FormData(form).get("reason") },
          });
          dialog.close();
          await loadOrders();
          flash("退款申请已提交，可在订单中查看进度。");
        } catch (error) {
          setMessage(document.getElementById("refund-message"), error.message);
        }
      });
    };
  }

  function supportGuides() {
    return faq([
      [
        "按下快捷键，没有打开切换面板",
        "先从 App 菜单栏选择显示切换器。如果菜单可以打开，请在快捷键设置中检查是否与其他软件冲突，再换一个组合。需要权限时，请按照 App 的提示在系统设置中开启辅助功能。",
      ],
      [
        "应用切换成功，窗口却不是我想要的",
        "应用模式会让目标应用回到前台，具体呈现哪个窗口由系统和应用决定。按 Tab 查看窗口模式时，只有可可靠识别和控制的窗口才会展开；其余保留应用入口。",
      ],
      [
        "付款后，App 仍提示未开通",
        "确认网页和 App 使用同一个邮箱。在订单中刷新付款状态，再回 App 同步已购权益。不要重复付款；仍有问题时，带上订单编号提交反馈。",
      ],
      [
        "浏览器登录了，却没有返回 App",
        "先确认 AppSwitcher 已安装并打开。在 App 内重新发起登录，浏览器显示电脑名称后点击确认登录，并允许打开 AppSwitcher。已过期的授权链接需要重新发起。",
      ],
      [
        "断网时能用吗？",
        "已经成功验证的试用或付费账号，可在已有授权有效期内离线使用，最长 7 天。超过本机验证期限需要联网同步；它并不是付费到期后额外赠送的 7 天。",
      ],
    ]);
  }

  async function support() {
    title("帮助与反馈");
    if (!state.me) {
      main.innerHTML = `<div class="page-width"><header class="page-heading"><h1>让问题，有个去处。</h1><p>先看看常见问题。需要进一步帮助，登录后可以提交反馈并追踪进度。</p></header><div class="support-grid"><section>${supportGuides()}</section><section class="support-card"><h2>联系支持</h2><p>登录后提交问题，保留完整的沟通记录。付款相关问题可关联订单。</p><a class="btn btn-primary" href="${loginURL()}" >登录并提交反馈</a>${supportEmail()}</section></div></div>`;
      return;
    }
    const orderId = new URLSearchParams(location.search).get("order") || "";
    main.innerHTML = accountShell(
      `<header class="workspace-heading"><div><h1>帮助与反馈</h1><p>描述你的问题，我们一起把使用体验理顺。</p></div></header><div class="support-grid"><section class="support-card"><h2>提交新反馈</h2><form id="support-form"><div class="field"><label for="ticket-subject">问题标题</label><input id="ticket-subject" name="subject" placeholder="例如：微信无法切到前台" required minlength="2" maxlength="160"></div><div class="field"><label for="ticket-order">关联订单编号（选填）</label><input id="ticket-order" name="orderId" value="${escape(orderId)}" maxlength="100" placeholder="与付款有关时填写"></div><div class="field"><label for="ticket-body">具体情况</label><textarea id="ticket-body" name="body" placeholder="请写下 macOS 与 App 版本、操作步骤、原本希望发生什么，以及实际看到的结果。" required minlength="5" maxlength="5000"></textarea><span class="field-hint">请勿填写密码、验证码、完整支付信息或工作内容。提交内容只用于处理你的问题。</span></div><button class="btn btn-primary" type="submit">提交反馈</button><div id="support-message"></div></form></section><section><h2>常见问题</h2>${supportGuides()}${supportEmail()}</section></div><div class="section-title"><h2>我的反馈记录</h2><button id="refresh-tickets" class="btn btn-quiet btn-small">刷新进度</button></div><div id="ticket-list" aria-live="polite"><div class="skeleton-line"></div><span class="sr-only">正在加载反馈</span></div>`,
    );
    bindLogout();
    const form = document.getElementById("support-form");
    form.onsubmit = (event) => {
      event.preventDefault();
      busy(form.querySelector("button"), async () => {
        const data = new FormData(form);
        try {
          const payload = {
            subject: data.get("subject"),
            body: data.get("body"),
          };
          if (data.get("orderId").trim())
            payload.orderId = data.get("orderId").trim();
          await api("/support", { method: "POST", data: payload });
          form.reset();
          document.getElementById("ticket-order").value = "";
          setMessage(
            document.getElementById("support-message"),
            "反馈已收到，你可以在下方查看记录并补充信息。",
            "success",
          );
          await loadTickets();
        } catch (error) {
          setMessage(document.getElementById("support-message"), error.message);
        }
      });
    };
    document.getElementById("refresh-tickets").onclick = (event) =>
      busy(event.currentTarget, loadTickets);
    await loadTickets();
  }

  function supportEmail() {
    const email = state.config.supportEmail;
    return email && /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email)
      ? `<p class="small">也可以发送邮件至 <a class="text-link" href="mailto:${encodeURIComponent(email)}">${escape(email)}</a></p>`
      : "";
  }

  async function loadTickets() {
    const container = document.getElementById("ticket-list");
    try {
      const result = await api("/support");
      container.innerHTML = result.tickets.length
        ? `<div class="ticket-list">${result.tickets.map((ticket) => `<article class="ticket-card"><details><summary>${escape(ticket.subject)}</summary><div class="ticket-meta">${label(ticket.status)} · ${date(ticket.createdAt)} · 北京时间<br>编号：<span class="mono">${escape(ticket.id)}</span></div><div class="ticket-messages">${ticket.messages.map((message) => `<div class="ticket-message ${message.fromSupport ? "from-support" : ""}"><div class="message-meta">${message.fromSupport ? "AppSwitcher 支持" : "我"} · ${date(message.createdAt)}</div>${escape(message.body)}</div>`).join("")}</div><form class="ticket-reply" data-ticket="${escape(ticket.id)}"><div class="field"><label for="reply-${escape(ticket.id)}">补充信息</label><textarea id="reply-${escape(ticket.id)}" name="body" required minlength="2" maxlength="5000" placeholder="在这里继续补充问题信息"></textarea></div><button class="btn btn-secondary btn-small" type="submit">发送补充</button><div class="reply-message"></div></form></details></article>`).join("")}</div>`
        : '<div class="empty-state"><h3>目前还没有反馈记录</h3><p>提交的问题会显示在这里，回复与进度都会保留。</p></div>';
      container.querySelectorAll("[data-ticket]").forEach(
        (form) =>
          (form.onsubmit = (event) => {
            event.preventDefault();
            busy(form.querySelector("button"), async () => {
              try {
                await api(
                  `/support/${encodeURIComponent(form.dataset.ticket)}/messages`,
                  {
                    method: "POST",
                    data: { body: new FormData(form).get("body") },
                  },
                );
                await loadTickets();
                const updated = [
                  ...container.querySelectorAll("[data-ticket]"),
                ].find((item) => item.dataset.ticket === form.dataset.ticket);
                if (updated) updated.closest("details").open = true;
                flash("补充信息已发送。");
              } catch (error) {
                setMessage(form.querySelector(".reply-message"), error.message);
              }
            });
          }),
      );
    } catch (error) {
      container.innerHTML = `${notice(error.message, "error")}<button id="retry-tickets" class="btn btn-secondary btn-small">重新加载</button>`;
      document.getElementById("retry-tickets").onclick = loadTickets;
    }
  }

  async function download() {
    title("下载与更新");
    const data = state.config.download;
    const url = data.available ? safeURL(data.url) : null;
    main.innerHTML = `<div class="page-width"><header class="page-heading"><h1>给你的 Mac，<br>一个更顺手的切换方式。</h1><p>安装、登录，开始你的 14 天体验。</p></header><div class="download-layout"><section class="download-lead"><div class="auth-key" aria-hidden="true">⌘</div><h2>AppSwitcher for Mac</h2><p>一次唤出，一个按键。<br>让应用切换成为自然的动作。</p>${url ? `<a class="btn btn-primary" href="${escape(url)}">下载 Mac 版${data.version ? ` · ${escape(data.version)}` : ""} <span aria-hidden="true">↓</span></a>` : '<button class="btn btn-primary" disabled>正式安装包准备中</button><div class="notice">正式下载尚未开放。我们正在完成面向普通用户的安装与更新验证，准备好后将在这里提供安装包。</div>'}<div class="system-spec"><span>macOS ${escape(data.minimumOS || "15.0")} 及以上</span><span>Apple Silicon 芯片</span></div><p class="small">Windows 版本尚未提供。账号不设设备上限，系统支持范围以本页为准。</p></section><section><ol class="install-steps"><li><h3>下载并放入应用程序</h3><p>打开下载的安装包，将 AppSwitcher 拖到“应用程序”文件夹，再从那里启动。</p></li><li><h3>完成权限引导</h3><p>按照 App 提示，在系统设置中允许辅助功能，用于识别和切换应用窗口。无需开启屏幕录制。</p></li><li><h3>登录，主动开始试用</h3><p>App 会打开浏览器。验证邮箱并确认电脑名称后返回 App，点击开始试用，才会启动 14 天计时。</p></li><li><h3>设置顺手的组合键</h3><p>在快捷键设置中选择唤出组合，打开面板，再按应用对应的键位。</p></li></ol></section></div><section class="faq-section"><h2>更新与安装帮助</h2>${faq(
      [
        [
          "已有旧版本，如何更新？",
          "先退出正在运行的 AppSwitcher，再将新版放入应用程序文件夹并替换旧版。不要删除 App 的用户数据文件夹。重新打开后，原有快捷键和偏好设置会继续保留。",
        ],
        [
          "系统提示无法验证开发者，怎么办？",
          "请先确认安装包来自本官网的正式下载入口，检查是否下载完整。如果仍被系统阻止，请联系支持。不要通过关闭系统安全保护来完成安装。",
        ],
        [
          "如何确认我的电脑是 Apple Silicon？",
          "在屏幕左上角的苹果菜单选择“关于本机”。芯片显示 Apple M 系列的电脑属于 Apple Silicon；当前安装包不支持 Intel 芯片。",
        ],
      ],
    )}<div class="section-title"><h2>版本说明</h2></div><div id="release-notes">${data.available ? '<p class="small">正在读取版本说明…</p>' : '<p class="small">正式版本发布后，将在此同步更新内容。</p>'}</div></section></div>`;
    if (data.available) {
      try {
        const release = await api("/releases/latest");
        document.getElementById("release-notes").innerHTML =
          `<p class="release-notes">${escape(release.notes || "本版本暂无补充说明。")}</p>`;
      } catch (error) {
        document.getElementById("release-notes").innerHTML = notice(
          `版本说明暂时无法读取。${error.message}`,
        );
      }
    }
  }

  async function authorize() {
    title("登录到 App");
    const request = new URLSearchParams(location.search).get("request");
    if (!request) {
      main.innerHTML =
        '<div class="page-width authorization"><h1>这个登录链接不完整</h1><p>请回到 AppSwitcher，重新点击登录。无需重新注册账号。</p><a class="btn btn-secondary" href="/support/">查看登录帮助</a></div>';
      return;
    }
    try {
      const result = await api(
        `/desktop/request?request=${encodeURIComponent(request)}`,
      );
      main.innerHTML = `<div class="page-width authorization"><div class="auth-key" aria-hidden="true">⌘</div><h1>把账号带回 AppSwitcher。</h1><p>确认是你正在使用的电脑，然后继续。</p><section class="auth-card"><dl><div><dt>登录账号</dt><dd>${escape(state.me.account.email)}</dd></div><div><dt>这台电脑</dt><dd>${escape(result.deviceName || "Mac 电脑")}</dd></div><div><dt>请求有效至（北京时间）</dt><dd>${date(result.expiresAt)}</dd></div></dl><button class="btn btn-primary full-width" id="approve-desktop">确认登录到这台电脑</button><a class="btn btn-quiet full-width" href="/account/">取消并返回账号</a><div id="authorize-message"></div></section><p class="small">只确认你自己刚刚发起的登录。确认后，浏览器将请求打开 AppSwitcher。</p></div>`;
      document.getElementById("approve-desktop").onclick = (event) =>
        busy(event.currentTarget, async () => {
          try {
            const approved = await api("/desktop/approve", {
              method: "POST",
              data: { request },
            });
            const callback = safeURL(approved.callbackUrl, { callback: true });
            if (!callback)
              throw new Error(
                "返回 App 的地址不正确，请在 App 内重新发起登录。",
              );
            document.querySelector(".authorization .auth-card").innerHTML =
              `${notice("登录已确认。允许浏览器打开 AppSwitcher，即可继续。", "success")}<a id="return-to-app" class="btn btn-primary full-width" href="${escape(callback)}">打开 AppSwitcher</a><p class="small">如果没有自动返回，请点击上方按钮。完成后可以关闭本页。</p>`;
            location.href = callback;
          } catch (error) {
            setMessage(
              document.getElementById("authorize-message"),
              error.message,
            );
          }
        });
    } catch (error) {
      main.innerHTML = `<div class="page-width authorization"><h1>暂时无法完成登录</h1>${notice(error.message, "error")}<p>请回到 AppSwitcher 重新发起登录，再使用新的链接确认。</p><a class="btn btn-secondary" href="/account/">返回账号中心</a></div>`;
    }
  }

  function legal(kind) {
    const privacy = kind === "privacy";
    title(privacy ? "隐私说明" : "服务与退款条款");
    const draft =
      state.config.environment !== "production"
        ? notice(
            "当前为上线前审阅稿。经营主体及联系信息将在正式开放前完成登记，请勿在开发预览中提交真实付款。",
          )
        : "";
    main.innerHTML = `<article class="page-width legal-page"><h1>${privacy ? "隐私说明" : "服务与退款条款"}</h1><p class="small">生效版本：${escape((privacy ? state.config.privacyVersion : state.config.termsVersion) || "待公布")}</p>${draft}${privacy ? `<p class="legal-intro">AppSwitcher 用于在本机切换应用与窗口。我们只处理提供账号、购买授权和售后所需的信息。</p><h2>切换时，哪些内容留在本机</h2><p>应用身份、使用排序和快捷键偏好保存在本机。辅助功能权限用于识别与控制窗口；窗口标题只在当前切换快照中使用，不上传、不持久化到服务器。我们不收集屏幕内容或按键原文，不申请屏幕录制来完成切换。</p><h2>账号与设备登录</h2><p>邮箱用于验证码登录和服务通知。服务器保存账号、授权期限、登录会话的电脑名称与时间，用于同步权益和让你主动退出设备。我们不采用硬件指纹限制设备台数。浏览器使用必要的登录与安全 Cookie，不通过本网站加载广告追踪或第三方分析脚本。</p><h2>付款与支持记录</h2><p>我们保存套餐、金额、支付渠道、订单状态、授权发放与退款记录，用于履行交易和处理售后。微信或支付宝按照各自规则处理你的付款信息；我们不要求你在本网站填写银行卡密码。反馈内容由你主动提交，请避免附带密码、验证码、工作窗口标题或他人的个人信息。</p><h2>保存、查阅与删除</h2><p>账号有效期间保存提供服务所需的信息。你可以在账号中心查阅订单、授权与登录会话，通过帮助与反馈提出更正、导出或注销请求。交易、争议和法律要求必须保留的记录不会因注销立即删除；处理请求时会说明适用范围。验证码与短期登录凭证按其有效期失效。</p><h2>安全与服务提供方</h2><p>正式服务通过 HTTPS 传输，登录凭证受访问控制保护。邮件服务和支付渠道只接收完成对应服务所需的信息。当前产品首发面向中国大陆用户，不以收集使用内容或出售个人信息作为商业模式。${state.config.legalEntityName ? `服务经营者：${escape(state.config.legalEntityName)}。` : "正式经营者将在上线前公示。"}</p><h2>如何联系</h2><p>如有隐私、账号或个人信息请求，请通过 <a href="/support/">帮助与反馈</a> 联系我们。我们会核实身份并回应处理进度。</p>` : `<p class="legal-intro">以下规则说明你如何试用、购买和续费，以及出现问题时怎样获得帮助。每次付款均由你主动发起，不包含自动扣款。</p><h2>产品范围与账号</h2><p>AppSwitcher 提供 macOS 应用切换、按能力展开的窗口切换和自定义快捷键。支持的系统与芯片以 <a href="/download/">下载页</a> 为准；Windows 版本尚未提供。应用模式不保证精确选中某个窗口。账号不限制设备数量、类型或同时在线台数，但应妥善保管邮箱和登录凭证。为处理明确的账号安全问题，我们可以暂停受影响会话并提供恢复路径。</p><h2>14 天全功能试用</h2><p>每个账号可使用一次连续 14×24 小时试用，不绑定付款方式。注册或下载不开始计时；在 App 内主动开始、服务器成功开通后计时。换电脑、重装或重新登录不重置试用。试用中购买会保留剩余试用时间；未开始试用而直接购买的账号不再追加免费试用。</p><h2>价格、期限与续费</h2><p>价格以购买页面与订单确认金额为准，人民币结算。月、季、年分别为 1、3、12 个日历月，功能相同。已有有效授权时，新购买接在连续有效期之后；已经到期时，从本次首次成功发放起重新计算，不追补停用期。月末没有对应日期时取月末，连续续费仍保留原始日期锚点。全部时间向用户显示为北京时间，到显示的截止时刻停止有效。</p><h2>离线与到期</h2><p>首次登录、首次开启试用和同步新购买需要联网。已验证设备可以在获批期限内最长离线使用 7 天；本地验证期不能超出真实授权期限，也不因重启而延长。超过验证期需要联网同步。到期后暂停新的核心切换操作，但保留配置、账号、订单、更新和帮助入口。恢复有效授权后，可以继续使用原有偏好。</p><h2>退款规则</h2><ul><li>首次付费订单，在支付成功后 7×24 小时内可申请全额退款。如我们延迟发放，至少保留实际发放后 7×24 小时的申请窗口。</li><li>尚未起算的续费订单，可申请该订单全额退款，不受首次购买 7 天窗口限制。</li><li>已经起算的非首次续费，通常不按剩余天数退款。误操作或无法使用可提交具体情况核查。</li><li>重复扣款、已付款未开通、确认的产品故障，单独核查补发或退款，不统一受上述 7 天窗口限制。此商业承诺不排除适用法律要求的消费者权利。</li></ul><p>在 <a href="/orders/">订单与退款</a> 提交申请。申请本身不立即撤销全部授权；渠道确认退款后，调整对应订单剩余期限，保留其他未退款订单。资金到账时间以支付渠道结果为准，处理进度会更新在订单中。</p><h2>更新与问题处理</h2><p>请通过官网正式下载入口更新，不需要关闭系统安全保护。更新应保留现有偏好；异常时可通过 <a href="/support/">帮助与反馈</a> 提交版本、操作步骤与订单编号。我们不要求你提供密码或验证码处理售后。付款未确认开通时，请先查单与同步，避免重复付款。</p><h2>条款变更与联系</h2><p>涉及已购权益的重要调整会提供清晰说明，不因价格变更减少已购买的期限。${state.config.legalEntityName ? `服务经营者：${escape(state.config.legalEntityName)}。联系渠道见下方或帮助与反馈页。` : "具体经营主体与联系方式将在正式收费前公示。"}有疑问时，请在购买前通过帮助与反馈联系我们。</p>`}${supportEmail()}</article>`;
  }

  async function render() {
    if (
      ["/account/", "/orders/", "/desktop/authorize/"].includes(route) &&
      !state.me
    ) {
      location.replace(loginURL());
      return;
    }
    switch (route) {
      case "/":
        home();
        break;
      case "/pricing/":
        pricing();
        break;
      case "/download/":
        await download();
        break;
      case "/login/":
        login();
        break;
      case "/account/":
        await account();
        break;
      case "/orders/":
        await orders();
        break;
      case "/support/":
        await support();
        break;
      case "/desktop/authorize/":
        await authorize();
        break;
      case "/privacy/":
        legal("privacy");
        break;
      case "/terms/":
        legal("terms");
        break;
      default:
        title("页面不存在");
        main.innerHTML =
          '<div class="standalone-error"><h1>这个页面暂时找不到。</h1><p>链接可能已经变化，请返回首页继续。</p><a class="btn btn-primary" href="/">返回首页</a></div>';
    }
  }

  async function start() {
    try {
      const [config, me] = await Promise.all([
        api("/config"),
        api("/me").catch((error) => {
          if (error.status === 401) return null;
          throw error;
        }),
      ]);
      state.config = config;
      state.me = me;
      if (config.environment !== "production") {
        const banner = document.getElementById("environment-notice");
        banner.textContent =
          config.payments.wechat || config.payments.alipay
            ? "开发预览 · 当前非正式环境，请勿提交真实付款"
            : "开发预览 · 仅验证产品流程，演示支付不会产生真实扣款";
        banner.hidden = false;
      }
      updateNav();
      await render();
    } catch (error) {
      main.innerHTML = `<div class="standalone-error"><h1>暂时连接不上服务。</h1><p>${escape(error.message)}</p><button class="btn btn-primary" id="retry-page">重新加载</button></div>`;
      document.getElementById("retry-page").onclick = () => location.reload();
    }
  }

  document.getElementById("copyright-year").textContent =
    new Date().getFullYear();
  document.getElementById("nav-toggle").onclick = (event) => {
    const open = event.currentTarget.getAttribute("aria-expanded") !== "true";
    event.currentTarget.setAttribute("aria-expanded", String(open));
    event.currentTarget.setAttribute(
      "aria-label",
      open ? "收起导航" : "展开导航",
    );
    event.currentTarget.textContent = open ? "收起" : "菜单";
    document.getElementById("site-nav").classList.toggle("is-open", open);
  };
  window.addEventListener("pagehide", () => clearTimeout(state.poll));
  start();
})();
