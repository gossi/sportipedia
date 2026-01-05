/**
This is very much based on:
https://www.npmjs.com/package/@kainstar/vite-plugin-i18next-loader

With slight adjustments
*/

import fs from 'node:fs';
import path from 'node:path';

import { setProperty } from 'dot-prop';
import { globbySync } from 'globby';
// eslint-disable-next-line import-x/default
import YAML from 'js-yaml';
import { createLogger } from 'vite';

import type { Options as GlobbyOptions } from 'globby';
import type { Plugin } from 'vite';

export interface Options {
  /**
   * Enable debug logging
   */
  debug?: boolean;
  /**
   * Locale top level directory paths ordered from least specialized to most specialized
   *  e.g. lib locale -> app locale
   *
   * Locales loaded later will overwrite any duplicated key via a deep merge strategy.
   */
  paths: string[];

  /**
   * i18next namespace
   *
   * @default 'translation'
   */
  intlNS?: string | false;

  /**
   * Glob patterns to match files
   *
   * @default ['**\/*.json', '**\/*.yml', '**\/*.yaml']
   */
  include?: string[];

  /**
   * custom globby options
   */
  globbyOptions?: GlobbyOptions;
}

export type ResBundle = Record<string, Record<string, unknown>>;

// don't export these from index so the external types are cleaner
export const IntlVirtualModuleId = 'virtual:ember-intl-loader';

export const IntlResolvedVirtualModuleId = `\0${IntlVirtualModuleId}`;

export function jsNormalizedLang(lang: string) {
  return lang.replaceAll('-', '_');
}

export function enumerateLangs(dir: string) {
  return fs.readdirSync(dir).filter(function (file) {
    return fs.statSync(path.join(dir, file)).isDirectory();
  });
}

export function resolvePaths(paths: string[], cwd: string) {
  return paths.map((override) => {
    return path.isAbsolute(override) ? override : path.join(cwd, override);
  });
}

export function assertExistence(paths: string[]) {
  for (const dir of paths) {
    if (!fs.existsSync(dir)) {
      throw new Error(`Directory does not exist: ${dir}`);
    }
  }
}

export function loadAndParse(langFile: string) {
  const fileContent = fs.readFileSync(langFile, 'utf8');
  const extname = path.extname(langFile);
  let parsedContent: Record<string, unknown> = {};

  try {
    parsedContent =
      extname === '.yaml' || extname === '.yml'
        ? (YAML.load(fileContent) as Record<string, unknown>)
        : (JSON.parse(fileContent) as Record<string, unknown>);
  } catch (error) {
    // eslint-disable-next-line @typescript-eslint/restrict-template-expressions
    throw new Error(`parsing file ${langFile}: ${error}`, {
      cause: error
    });
  }

  return parsedContent;
}

export const intl = ({
  paths,
  include = ['**/*.json', '**/*.yml', '**/*.yaml'],
  globbyOptions,
  debug
}: Options) => {
  const log = createLogger('info', { prefix: '[ember-intl/vite]' });

  function loadLocales() {
    const localeDirs = resolvePaths(paths, process.cwd());

    assertExistence(localeDirs);

    const appResBundle: ResBundle = {};
    const loadedFiles: string[] = [];
    let allLangs = new Set<string>();

    for (const nextLocaleDir of localeDirs) {
      // all subdirectories match language codes
      const langs = enumerateLangs(nextLocaleDir);

      allLangs = new Set([...allLangs, ...langs]);

      for (const lang of langs) {
        const langDir = path.join(nextLocaleDir, lang); // top level lang dir
        const langFiles = globbySync(include, {
          ...globbyOptions,
          cwd: langDir,
          absolute: true
        }); // all lang files matching patterns in langDir

        for (const langFile of langFiles) {
          loadedFiles.push(langFile); // track for fast hot reload matching

          const content = loadAndParse(langFile);

          const namespaceFilepath = path.relative(langDir, langFile);
          const extname = path.extname(langFile);
          const namespaceParts = namespaceFilepath.replace(extname, '').split(path.sep);
          const namespace = [lang, ...namespaceParts]
            .filter(Boolean) // remove empty str
            .join('.');

          setProperty(appResBundle, namespace, content);
        }
      }
    }

    if (debug) {
      log.info(
        `Bundling locales (ordered least specific to most):\n${loadedFiles.map((f) => `\t${f}`).join('\n')}`,
        {
          timestamp: true
        }
      );
    }

    // one bundle - works, no issues with dashes in names
    // const bundle = `export default ${JSON.stringify(appResBundle)}`

    // named exports, requires manipulation of names
    let namedBundle = '';
    let defaultExport = 'const resources = { \n';

    for (const lang of allLangs) {
      const langIdentifier = jsNormalizedLang(lang);

      namedBundle += `export const ${langIdentifier} = ${JSON.stringify(appResBundle[lang])}\n`;
      defaultExport += `"${lang}": ${langIdentifier},\n`;
    }

    defaultExport += '}';
    defaultExport += '\nexport default resources\n';

    const bundle = namedBundle + defaultExport;

    if (debug) {
      log.info(`Locales module '${IntlResolvedVirtualModuleId}':\n${bundle}`, {
        timestamp: true
      });
    }

    return bundle;
  }

  const plugin: Plugin = {
    name: 'vite-plugin-ember-intl', // required, will show up in warnings and errors
    resolveId(id) {
      if (id === IntlVirtualModuleId) {
        return IntlResolvedVirtualModuleId;
      }

      return;
    },
    load(id) {
      if (id !== IntlResolvedVirtualModuleId) {
        return;
      }

      return loadLocales();
    },

    /**
     * Watch translation files and trigger an update.
     */
    async handleHotUpdate({ file, server }) {
      // eslint-disable-next-line @typescript-eslint/restrict-template-expressions
      log.info(`hot update ${file}, ${paths}`);

      const isLocaleFile =
        /\.(json|yml|yaml)$/.exec(file) &&
        paths.some((p) => file.startsWith(path.join(process.cwd(), p)));

      if (isLocaleFile) {
        log.info(`Changed locale file: ${file}`, {
          timestamp: true
        });

        const { moduleGraph } = server;

        const module = moduleGraph.getModuleById(IntlResolvedVirtualModuleId);

        if (module) {
          await server.reloadModule(module);
        }
      }
    }
  };

  return plugin;
};
