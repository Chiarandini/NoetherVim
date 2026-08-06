// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// Served as a subpath of the personal site. The Angular SPA occupies the
// domain root; this bundle is copied into dist/testing/noethervim/ by
// website-nate's deploy workflow.
export default defineConfig({
  site: 'https://nathanaelsrawley.com',
  base: '/noethervim',
  trailingSlash: 'always',
  integrations: [
    starlight({
      title: 'NoetherVim',
      description:
        'A Neovim distribution with a minimal abstraction layer. LaTeX first-class, opt-in bundles, override anything in plain Lua.',
      // Alpha ships breaking changes without deprecation shims, and the docs
      // track main rather than a release. The banner saying so is applied to
      // every route from src/routeData.ts.
      routeMiddleware: './src/routeData.ts',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/Chiarandini/NoetherVim',
        },
      ],
      editLink: {
        baseUrl: 'https://github.com/Chiarandini/NoetherVim/edit/main/docs-site/',
      },
      customCss: ['./src/styles/custom.css'],
      sidebar: [
        {
          label: 'Start here',
          items: [
            { label: 'Introduction', link: '/' },
            { label: 'Installation', link: '/start/install/' },
            { label: 'Your first session', link: '/start/first-session/' },
            { label: 'For mathematicians', link: '/start/mathematicians/' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Bundles', link: '/guides/bundles/' },
            { label: 'Configuration', link: '/guides/configuration/' },
            { label: 'Keybinding philosophy', link: '/guides/keybindings/' },
            { label: 'Recipes', link: '/guides/recipes/' },
            { label: 'Managing your install', link: '/guides/managing/' },
          ],
        },
      ],
    }),
  ],
});
