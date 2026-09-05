export interface Env {
  MAYAR_API_KEY: string;
  MAYAR_ENV: string;
  MAYAR_PRODUCT_ID: string;
}

interface VerifyRequest {
  licenseCode?: unknown;
}

interface MayarLicenseCode {
  licenseCode?: string;
  status?: string;
}

interface MayarSoftwareVerifyResponse {
  statusCode?: number;
  messages?: string;
  message?: string;
  isLicenseActive?: boolean;
  licenseCode?: MayarLicenseCode;
}

type ClientError = "invalid" | "inactive" | "not_found" | "limit" | "upstream";

const MAYAR_ORIGIN: Record<"sandbox" | "production", string> = {
  sandbox: "https://api.mayar.club",
  production: "https://api.mayar.id",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/license/verify") {
      return json({ active: false, error: "invalid" }, 404);
    }

    const config = readConfig(env);
    if (!config) {
      return json({ active: false, error: "upstream" }, 500);
    }

    let body: VerifyRequest;
    try {
      body = (await request.json()) as VerifyRequest;
    } catch {
      return json({ active: false, error: "invalid" }, 400);
    }

    const licenseCode =
      typeof body.licenseCode === "string" ? body.licenseCode.trim() : "";
    if (!licenseCode) {
      return json({ active: false, error: "invalid" }, 400);
    }

    try {
      const result = await verifyWithMayar(config, licenseCode);
      if (result.active) {
        return json({ active: true });
      }
      return json({ active: false, error: result.error }, result.status);
    } catch {
      return json({ active: false, error: "upstream" }, 502);
    }
  },
};

function readConfig(env: Env): {
  apiKey: string;
  environment: "sandbox" | "production";
  productId: string;
} | null {
  const apiKey = env.MAYAR_API_KEY?.trim();
  const productId = env.MAYAR_PRODUCT_ID?.trim();
  if (!apiKey || !productId) {
    return null;
  }
  return {
    apiKey,
    environment: env.MAYAR_ENV === "production" ? "production" : "sandbox",
    productId,
  };
}

async function verifyWithMayar(
  config: { apiKey: string; environment: "sandbox" | "production"; productId: string },
  licenseCode: string,
): Promise<{ active: true } | { active: false; error: ClientError; status: number }> {
  const software = await verifyMayarPath(
    config,
    licenseCode,
    "/software/v2/license/verify",
  );
  if (software.active) {
    return software;
  }
  if (software.error === "upstream" || software.error === "limit") {
    return software;
  }
  return verifyMayarPath(config, licenseCode, "/saas/v2/license/verify");
}

async function verifyMayarPath(
  config: { apiKey: string; environment: "sandbox" | "production"; productId: string },
  licenseCode: string,
  path: "/software/v2/license/verify" | "/saas/v2/license/verify",
): Promise<{ active: true } | { active: false; error: ClientError; status: number }> {
  const response = await fetch(`${MAYAR_ORIGIN[config.environment]}${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      licenseCode,
      productId: config.productId,
    }),
  });

  let payload: MayarSoftwareVerifyResponse = {};
  try {
    payload = (await response.json()) as MayarSoftwareVerifyResponse;
  } catch {
    return { active: false, error: "upstream", status: 502 };
  }

  const statusCode = payload.statusCode ?? response.status;
  const message = `${payload.messages ?? payload.message ?? ""}`.toLowerCase();

  if (response.status === 429 || statusCode === 429) {
    return { active: false, error: "upstream", status: 502 };
  }
  if (response.status === 401 || statusCode === 401) {
    return { active: false, error: "upstream", status: 502 };
  }
  if (response.status === 404 || statusCode === 404) {
    return { active: false, error: "not_found", status: 404 };
  }
  if (isActivationLimit(message, statusCode, response.status)) {
    return { active: false, error: "limit", status: 400 };
  }
  if (!response.ok || statusCode >= 400) {
    return { active: false, error: "invalid", status: 400 };
  }

  const status = payload.licenseCode?.status?.toUpperCase();
  if (payload.isLicenseActive === true && (status === undefined || status === "ACTIVE")) {
    return { active: true };
  }
  return { active: false, error: "inactive", status: 200 };
}

function isActivationLimit(message: string, statusCode: number, httpStatus: number): boolean {
  if (message.includes("activation limit") || message.includes("maximum activation")) {
    return true;
  }
  return (httpStatus === 400 || statusCode === 400) && message.includes("limit");
}

function json(
  body: { active: boolean; error?: ClientError },
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  };
}
