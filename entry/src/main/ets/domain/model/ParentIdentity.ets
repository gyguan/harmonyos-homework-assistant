export enum ParentIdentity {
  DAD = 'DAD',
  MOM = 'MOM'
}

export class ParentIdentityHelper {
  static label(identity: ParentIdentity): string {
    return identity === ParentIdentity.MOM ? '妈妈' : '爸爸';
  }

  static badge(identity: ParentIdentity): string {
    return identity === ParentIdentity.MOM ? '妈' : '爸';
  }
}
