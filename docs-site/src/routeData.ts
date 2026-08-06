import { defineRouteMiddleware } from '@astrojs/starlight/route-data';

// Starlight's `banner` is a per-page frontmatter field. The alpha warning
// belongs on every page, and the generated pages are rewritten on each sync,
// so set it here rather than in eight separate frontmatter blocks.
const BANNER =
  'NoetherVim is <strong>alpha</strong>. Breaking changes land without deprecation shims. ' +
  'These docs track <code>main</code>.';

export const onRequest = defineRouteMiddleware((context) => {
  const { entry } = context.locals.starlightRoute;
  entry.data.banner ??= { content: BANNER };
});
