import { useState, useCallback } from "preact/hooks";
import { useT } from "../../../shared/i18n/context";
import type { TranslationKey } from "../../../shared/i18n/translations";

interface AddAccountProps {
  visible: boolean;
  onSubmitRelay: (callbackUrl: string) => Promise<void>;
  onImportToken?: (tokenData: any, skipRefresh?: boolean) => Promise<{ success: boolean; error?: string }>;
  onRefresh?: () => Promise<void>;
  addInfo: string;
  addError: string;
}

export function AddAccount({ visible, onSubmitRelay, onImportToken, onRefresh, addInfo, addError }: AddAccountProps) {
  const t = useT();
  const [input, setInput] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [importing, setImporting] = useState(false);

  const handleSubmit = useCallback(async () => {
    setSubmitting(true);
    await onSubmitRelay(input);
    setSubmitting(false);
    setInput("");
  }, [input, onSubmitRelay]);

  const handleFileUpload = useCallback(async (e: Event) => {
    const files = (e.target as HTMLInputElement).files;
    if (!files || files.length === 0 || !onImportToken) return;

    setImporting(true);
    let successCount = 0;
    let failCount = 0;
    const errors: string[] = [];

    try {
      // Import all files without refreshing
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        try {
          const text = await file.text();
          const tokenData = JSON.parse(text);
          const result = await onImportToken(tokenData, true);
          if (result.success) {
            successCount++;
          } else {
            failCount++;
            errors.push(`${file.name}: ${result.error || "Unknown error"}`);
          }
        } catch (err) {
          failCount++;
          const errMsg = err instanceof Error ? err.message : "Invalid format";
          errors.push(`${file.name}: ${errMsg}`);
          console.error(`Failed to import ${file.name}:`, err);
        }
      }

      // Refresh once after all imports
      if (successCount > 0 && onRefresh) {
        await onRefresh();
      }

      if (successCount > 0) {
        alert(`成功导入 ${successCount} 个账号${failCount > 0 ? `，失败 ${failCount} 个` : ""}`);
      }
      if (errors.length > 0) {
        console.error("Import errors:", errors);
        if (successCount === 0) {
          alert(`导入失败:\n${errors.join("\n")}`);
        }
      }

      (e.target as HTMLInputElement).value = "";
    } finally {
      setImporting(false);
    }
  }, [onImportToken, onRefresh]);

  return (
    <>
      {addInfo && (
        <p class="text-sm text-primary">{t(addInfo as TranslationKey)}</p>
      )}
      {addError && (
        <p class="text-sm text-red-500">{t(addError as TranslationKey)}</p>
      )}
      {onImportToken && (
        <section class="bg-white dark:bg-card-dark border border-gray-200 dark:border-border-dark rounded-xl p-5 shadow-sm transition-colors">
          <div class="flex items-center gap-3">
            <label class="flex-1 cursor-pointer">
              <input
                type="file"
                accept=".json"
                onChange={handleFileUpload}
                disabled={importing}
                multiple
                class="hidden"
              />
              <div class="px-4 py-2.5 bg-slate-50 dark:bg-bg-dark border border-gray-200 dark:border-border-dark rounded-lg text-sm font-medium text-slate-700 dark:text-text-main hover:bg-slate-100 dark:hover:bg-border-dark transition-colors text-center">
                {importing ? "导入中..." : "📁 导入 Token 文件"}
              </div>
            </label>
            <span class="text-xs text-slate-400 dark:text-text-dim">支持 .json 格式</span>
          </div>
        </section>
      )}
      {visible && (
        <section class="bg-white dark:bg-card-dark border border-gray-200 dark:border-border-dark rounded-xl p-5 shadow-sm transition-colors">
          <ol class="text-sm text-slate-500 dark:text-text-dim mb-4 space-y-1.5 list-decimal list-inside">
            <li dangerouslySetInnerHTML={{ __html: t("addStep1") }} />
            <li dangerouslySetInnerHTML={{ __html: t("addStep2") }} />
            <li dangerouslySetInnerHTML={{ __html: t("addStep3") }} />
          </ol>
          <div class="flex gap-3 mb-3">
            <input
              type="text"
              value={input}
              onInput={(e) => setInput((e.target as HTMLInputElement).value)}
              placeholder={t("pasteCallback")}
              class="flex-1 px-3 py-2.5 bg-slate-50 dark:bg-bg-dark border border-gray-200 dark:border-border-dark rounded-lg text-sm font-mono text-slate-600 dark:text-text-main focus:ring-2 focus:ring-primary/50 focus:border-primary outline-none transition-colors"
            />
            <button
              onClick={handleSubmit}
              disabled={submitting}
              class="px-4 py-2.5 bg-white dark:bg-card-dark border border-gray-200 dark:border-border-dark rounded-lg text-sm font-medium text-slate-700 dark:text-text-main hover:bg-slate-50 dark:hover:bg-border-dark transition-colors"
            >
              {submitting ? t("submitting") : t("submit")}
            </button>
          </div>
        </section>
      )}
    </>
  );
}
