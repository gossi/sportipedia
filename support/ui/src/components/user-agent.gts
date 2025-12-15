/** eslint-disable @typescript-eslint/no-unsafe-assignment */
import { hash } from '@ember/helper';

import { UAParser } from 'ua-parser-js';
import { DeviceType } from 'ua-parser-js/enums';

import {
  Android,
  Apple,
  Archlinux,
  Chrome,
  Debian,
  Fedora,
  Firefox,
  FreeBSD,
  Google,
  Microsoft,
  MicrosoftEdge,
  Safari,
  Samsung,
  Tux,
  Ubuntu,
  Windows
} from '#/icons/logos.gts';
import Wearable from '~icons/material-symbols/devices-wearables-rounded';
import XR from '~icons/material-symbols/head-mounted-device-rounded';
import Laptop from '~icons/material-symbols/laptop-mac-outline';
import Phone from '~icons/material-symbols/phone-android';
import Console from '~icons/material-symbols/stadia-controller';
import Tablet from '~icons/material-symbols/tablet-outline';
import Tv from '~icons/material-symbols/tv-outline';

import { Icon } from '@hokulea/ember';

import type { TOC } from '@ember/component/template-only';
import type { Logo } from '#/icons/logos.gts';
import type { IBrowser, IDevice, IOS } from 'ua-parser-js';

const BrowserIconMap: Record<string, Logo> = {
  Firefox: Firefox as Logo,
  'Mobile Firefox': Firefox as Logo,
  Chrome: Chrome as Logo,
  'Mobile Chrome': Chrome as Logo,
  Edge: MicrosoftEdge as Logo,
  Safari: Safari as Logo,
  'Mobile Safari': Safari as Logo
};

function getBrowserIcon(name?: string): Logo | undefined {
  return name
    ? Object.hasOwn(BrowserIconMap, name)
      ? BrowserIconMap[name]
      : undefined
    : undefined;
}

const BrowserIcon: TOC<{ Args: { name: string } }> = <template>
  {{#let (getBrowserIcon @name) as |BI|}}
    <BI />
  {{/let}}
</template>;

const Browser: TOC<{ Args: { browser: IBrowser } }> = <template>
  <div class="info">
    {{#if @browser.name}}
      <span part="icon"><BrowserIcon @name={{@browser.name}} /></span>

      <span part="version">{{@browser.version}}</span>
      <span part="name">{{@browser.name}}</span>
    {{/if}}
  </div>
</template>;

const VendorIconMap: Record<string, Logo> = {
  Apple: Apple as Logo,
  Microsoft: Microsoft as Logo,
  Samsung: Samsung as Logo,
  Google: Google as Logo
};

function getVendorIcon(vendor?: string): Logo | undefined {
  return vendor
    ? Object.hasOwn(VendorIconMap, vendor)
      ? VendorIconMap[vendor]
      : undefined
    : undefined;
}

const OSIconMap: Record<string, Logo> = {
  Android: Android as Logo,
  Arch: Archlinux as Logo,
  Debian: Debian as Logo,
  Fedora: Fedora as Logo,
  FreeBSD: FreeBSD as Logo,
  iOS: Apple,
  Linux: Tux as Logo,
  macOS: Apple,
  Ubuntu: Ubuntu as Logo,
  Windows: Windows as Logo
};

function getOSIcon(name?: string): Logo | undefined {
  return name ? (Object.hasOwn(OSIconMap, name) ? OSIconMap[name] : undefined) : undefined;
}

const VendorIcon: TOC<{ Args: { name?: string } }> = <template>
  {{#let (getVendorIcon @name) as |VI|}}
    {{#if VI}}
      {{! @glint-ignore }}
      <Icon @icon={{VI}} />
    {{/if}}
  {{/let}}
</template>;

const DeviceIconMap: Record<string, Logo> = {
  [DeviceType.DESKTOP]: Laptop as Logo,
  [DeviceType.MOBILE]: Phone as Logo,
  [DeviceType.WEARABLE]: Wearable as Logo,
  [DeviceType.CONSOLE]: Console as Logo,
  [DeviceType.SMARTTV]: Tv as Logo,
  [DeviceType.TABLET]: Tablet as Logo,
  [DeviceType.XR]: XR as Logo
};

function getDeviceIcon(device: IDevice): Logo {
  const type = Object.keys(DeviceIconMap).find((t) => device.is(t));

  if (type) {
    return DeviceIconMap[type] as Logo;
  }

  return Laptop as Logo;
}

const DeviceIcon: TOC<{ Args: { device: IDevice } }> = <template>
  {{#let (getDeviceIcon @device) as |DI|}}
    <DI />
  {{/let}}
</template>;

const Device: TOC<{ Args: { device: IDevice } }> = <template>
  <div class="info">
    <span part="icon"><DeviceIcon @device={{@device}} /></span>
    <span part="name">{{@device.model}}</span>
    <span part="vendor">{{@device.vendor}}</span>
  </div>
</template>;

const OS: TOC<{ Args: { os: IOS } }> = <template>
  <div class="info">
    <span part="icon">
      {{#let (getOSIcon @os.name) as |OSIcon|}}
        <OSIcon />
      {{/let}}
    </span>
    <span part="version">{{@os.version}}</span>
    <span part="name">{{@os.name}}</span>
  </div>
</template>;

const UserAgent: TOC<{ Args: { userAgent: string } }> = <template>
  {{#let (UAParser @userAgent) as |ua|}}
    {{yield
      (hash
        Device=(component Device device=ua.device)
        DeviceIcon=(component DeviceIcon ua=ua)
        Browser=(component Browser browser=ua.browser)
        BrowserIcon=(component BrowserIcon browser=ua.browser)
        OS=(component OS os=ua.os)
      )
    }}
  {{/let}}
</template>;

export { UserAgent };
