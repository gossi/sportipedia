import { RequestPasswordResetPage } from '@sportipedia/user';

import { auth } from '#auth/client';

const RequestPasswordResetTemplate = <template>
  <RequestPasswordResetPage @auth={{auth}} />
</template>;

export { RequestPasswordResetTemplate };
