import { app } from "../../scripts/app.js";

const WORKFLOW = "16_IMAGE_All_In_One.json";
const STUDIO = "/extensions/slot_studio_autoload/studio/index.html";

// True when the canvas shows ComfyUI's stock sample graph (or nothing at all).
function isStockGraph() {
  const nodes = app.graph?._nodes ?? [];
  if (nodes.length === 0) return true;
  // The stock sample is a handful of nodes; the big all-in-one graph also names Z-Image, so check the size too.
  return nodes.length < 20 && nodes.some((n) => (n.widgets_values ?? []).includes("z_image_turbo_bf16.safetensors"));
}

// Small always-visible button that opens the Freepik-style Slot Studio page.
function addStudioButton() {
  if (document.getElementById("slot-studio-btn")) return;
  const b = document.createElement("a");
  b.id = "slot-studio-btn";
  b.href = STUDIO;
  b.onclick = () => { b.href = STUDIO + "?v=" + Date.now(); };
  b.target = "_blank";
  b.textContent = "Slot Studio";
  b.title = "Open the simple image studio (models, styles, edit, gallery)";
  Object.assign(b.style, {
    position: "fixed", left: "64px", bottom: "14px", zIndex: 1000, padding: "7px 12px",
    background: "#3b82f6", color: "#fff", borderRadius: "8px", font: "600 13px Segoe UI, sans-serif",
    textDecoration: "none", boxShadow: "0 2px 8px #0006",
  });
  document.body.appendChild(b);
}

app.registerExtension({
  name: "SlotStudio.AutoloadSymbolWorkflow",
  async setup() {
    addStudioButton();
    // Give the frontend a moment to restore the previous session first.
    await new Promise((r) => setTimeout(r, 1500));
    if (!isStockGraph()) return;
    const res = await fetch("/api/userdata/" + encodeURIComponent("workflows/" + WORKFLOW));
    if (!res.ok) return;
    await app.loadGraphData(await res.json(), true, true, WORKFLOW);
  },
});
