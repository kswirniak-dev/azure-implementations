resource rgLock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'lock-no-delete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Securing shared resources from accidental deletion'
  }
}
